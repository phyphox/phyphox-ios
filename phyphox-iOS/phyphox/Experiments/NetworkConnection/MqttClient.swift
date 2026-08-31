//
//  MqttClient.swift
//  phyphox
//
//  Created by Sebastian Staacks on 10.08.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import Foundation
import Network

protocol MqttClientDelegate: AnyObject {
    func mqttMessage(topic: String, payload: Data)
    func mqttConnected()
    func mqttConnectionLost(reason: String)
}

/**
 A minimal, dependency-free MQTT 3.1.1 client covering exactly what phyphox needs: connect (plain
 or TLS, with optional username/password), publish (QoS 0 and 1), subscribe to a single topic,
 keep the connection alive, and reconnect if it drops. It replaces CocoaMQTT and matches the
 equivalent from-scratch client on Android (NetworkConnection/Mqtt/MqttClient.java).

 QoS 2 is intentionally not implemented: phyphox does not need exactly-once delivery. The former
 "persistence" mode used QoS 2, but at-least-once (QoS 1) together with phyphox's own message
 buffer covers the reliability case. See network-mqtts-unofficial in phyphox-docs.

 Threading: all work happens on a single serial dispatch queue, which is also the queue the
 NWConnection delivers its events on, so socket writes never interleave. The connected/subscribed
 flags are additionally lock-protected as they are polled from the analysis thread.
 */
final class MqttClient {

    // MQTT control packet types (high nibble of the fixed-header byte)
    static let CONNECT = 1, CONNACK = 2, PUBLISH = 3, PUBACK = 4,
               SUBSCRIBE = 8, SUBACK = 9, PINGREQ = 12, PINGRESP = 13, DISCONNECT = 14

    private static let connectTimeout = 8.0
    private static let reconnectMin = 2.0, reconnectMax = 30.0

    //TLS ("mqtts") configuration: no customCACertificate means the system trust store. A custom
    //CA is used as the only trust anchor for the broker's chain, without host name verification,
    //which suits a pinned self-hosted broker (see network-mqtts-unofficial in phyphox-docs).
    struct TLSConfig {
        let customCACertificate: SecCertificate?
    }

    private let host: String
    private let port: UInt16
    private let clientId: String
    private let username: String? // nil if none
    private let password: String? // nil if none
    private let cleanSession: Bool
    private let keepAliveSeconds: Int
    private let tls: TLSConfig? // nil for a plain TCP connection
    private let subscribeTopic: String // "" if the client only publishes
    private weak var delegate: MqttClientDelegate?

    private let queue = DispatchQueue(label: "de.rwth-aachen.phyphox.mqtt")

    private var connection: NWConnection? = nil
    private var awaitingConnack = false
    private var closing = false
    private var lastWrite: TimeInterval = 0.0
    private var reconnectDelay = MqttClient.reconnectMin
    private var packetIdCounter: UInt16 = 0
    private var connectTimeoutItem: DispatchWorkItem? = nil
    private var keepAliveTimer: DispatchSourceTimer? = nil

    private let stateLock = NSLock()
    private var _connected = false
    private var _subscribed = false
    private(set) var connected: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _connected }
        set { stateLock.lock(); defer { stateLock.unlock() }; _connected = newValue }
    }
    private(set) var subscribed: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _subscribed }
        set { stateLock.lock(); defer { stateLock.unlock() }; _subscribed = newValue }
    }

    init(host: String, port: UInt16, clientId: String, username: String?, password: String?, cleanSession: Bool, keepAliveSeconds: Int, tls: TLSConfig?, subscribeTopic: String, delegate: MqttClientDelegate) {
        self.host = host
        self.port = port
        self.clientId = clientId
        self.username = username
        self.password = password
        self.cleanSession = cleanSession
        self.keepAliveSeconds = keepAliveSeconds > 0 ? keepAliveSeconds : 60
        self.tls = tls
        self.subscribeTopic = subscribeTopic
        self.delegate = delegate
    }

    /// Connects asynchronously. Returns immediately; success/failure is reported via the delegate.
    func connect() {
        queue.async {
            self.closing = false
            self.attemptConnect()
        }
    }

    /// Publishes asynchronously; QoS may be 0 or 1.
    func publish(topic: String, payload: Data, qos: Int) {
        queue.async {
            guard self.connected else {
                return
            }
            self.send(packet: MqttClient.buildPublishPacket(topic: topic, payload: payload, qos: qos, packetId: qos > 0 ? self.nextPacketId() : 0))
        }
    }

    /// Closes the connection and does not reconnect.
    func disconnect() {
        queue.async {
            self.closing = true
            if let connection = self.connection, self.connected {
                connection.send(content: Data([UInt8(MqttClient.DISCONNECT << 4), 0x00]), completion: .contentProcessed({ _ in
                    self.closeSocket()
                }))
            } else {
                self.closeSocket()
            }
        }
    }

    // MARK: - Connection (all on queue)

    private func attemptConnect() {
        if closing {
            return
        }

        let parameters: NWParameters
        if let tls = tls {
            let tlsOptions = NWProtocolTLS.Options()
            if let ca = tls.customCACertificate {
                sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { _, sec_trust, complete in
                    let trust = sec_trust_copy_ref(sec_trust).takeRetainedValue()
                    SecTrustSetAnchorCertificates(trust, [ca] as CFArray)
                    SecTrustSetAnchorCertificatesOnly(trust, true)
                    //The pinned custom CA authenticates the broker by itself: use a basic X.509
                    //policy without host name verification, like Android
                    SecTrustSetPolicies(trust, SecPolicyCreateBasicX509())
                    var error: CFError? = nil
                    complete(SecTrustEvaluateWithError(trust, &error))
                }, queue)
            }
            parameters = NWParameters(tls: tlsOptions)
        } else {
            parameters = NWParameters.tcp
        }

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            scheduleReconnect(reason: "invalid port \(port)")
            return
        }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: parameters)
        self.connection = connection
        awaitingConnack = true

        let timeoutItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.connection === connection, !self.connected else {
                return
            }
            connection.stateUpdateHandler = nil
            connection.cancel()
            self.connection = nil
            self.awaitingConnack = false
            if !self.closing {
                self.scheduleReconnect(reason: "connection timed out")
            }
        }
        connectTimeoutItem = timeoutItem
        queue.asyncAfter(deadline: .now() + MqttClient.connectTimeout, execute: timeoutItem)

        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self, self.connection === connection else {
                return
            }
            switch state {
            case .ready:
                self.socketReady()
            case .failed(let error):
                self.connectionLost(reason: error.localizedDescription)
            case .waiting(_):
                break //Keep waiting: the connect timeout decides when to give up
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func socketReady() {
        send(packet: MqttClient.buildConnectPacket(clientId: clientId, username: username, password: password, cleanSession: cleanSession, keepAliveSeconds: keepAliveSeconds))
        readPacket()
    }

    private func scheduleReconnect(reason: String) {
        delegate?.mqttConnectionLost(reason: reason)
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, MqttClient.reconnectMax)
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, !self.closing else {
                return
            }
            self.attemptConnect()
        }
    }

    private func connectionLost(reason: String) {
        if !connected && !awaitingConnack {
            return //Already handled: several error paths may fire for the same drop
        }
        closeSocket()
        if !closing {
            scheduleReconnect(reason: reason)
        }
    }

    private func closeSocket() {
        connected = false
        subscribed = false
        awaitingConnack = false
        connectTimeoutItem?.cancel()
        connectTimeoutItem = nil
        keepAliveTimer?.cancel()
        keepAliveTimer = nil
        if let connection = connection {
            connection.stateUpdateHandler = nil
            connection.cancel()
        }
        connection = nil
    }

    // MARK: - Reader (all on queue)

    private func receiveExactly(_ length: Int, from connection: NWConnection, completion: @escaping (Data) -> Void) {
        guard length > 0 else {
            completion(Data())
            return
        }
        connection.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self] data, _, _, error in
            guard let self = self, self.connection === connection else {
                return
            }
            guard let data = data, data.count == length, error == nil else {
                self.connectionLost(reason: "connection lost: \(error?.localizedDescription ?? "connection closed by broker")")
                return
            }
            completion(data)
        }
    }

    //Remaining Length is a Variable Byte Integer (1-4 bytes, 7 bits each, high bit = continuation)
    private func receiveRemainingLength(from connection: NWConnection, value: Int = 0, multiplier: Int = 1, count: Int = 0, completion: @escaping (Int) -> Void) {
        guard count <= 4 else {
            connectionLost(reason: "malformed remaining length")
            return
        }
        receiveExactly(1, from: connection) { data in
            let digit = Int(data[data.startIndex])
            let newValue = value + (digit & 0x7f) * multiplier
            if digit & 0x80 != 0 {
                self.receiveRemainingLength(from: connection, value: newValue, multiplier: multiplier * 128, count: count + 1, completion: completion)
            } else {
                completion(newValue)
            }
        }
    }

    private func readPacket() {
        guard let connection = connection else {
            return
        }
        receiveExactly(1, from: connection) { header in
            let headerByte = header[header.startIndex]
            self.receiveRemainingLength(from: connection) { remaining in
                self.receiveExactly(remaining, from: connection) { body in
                    self.handlePacket(type: Int(headerByte >> 4) & 0x0f, flags: Int(headerByte) & 0x0f, body: body)
                    self.readPacket()
                }
            }
        }
    }

    private func handlePacket(type: Int, flags: Int, body: Data) {
        if awaitingConnack {
            //The first packet from the broker must be the CONNACK answering our CONNECT
            guard type == MqttClient.CONNACK, body.count >= 2 else {
                connectionLost(reason: "malformed CONNACK")
                return
            }
            let returnCode = Int(body[body.startIndex + 1])
            guard returnCode == 0 else {
                connectionLost(reason: MqttClient.connackMessage(returnCode))
                return
            }
            awaitingConnack = false
            connected = true
            subscribed = false
            reconnectDelay = MqttClient.reconnectMin
            connectTimeoutItem?.cancel()
            connectTimeoutItem = nil
            startKeepAlive()
            if !subscribeTopic.isEmpty {
                send(packet: MqttClient.buildSubscribePacket(topic: subscribeTopic, qos: 0, packetId: nextPacketId()))
            } else {
                subscribed = true //nothing to subscribe to, so treat as ready
            }
            delegate?.mqttConnected()
            return
        }
        switch type {
        case MqttClient.PUBLISH:
            let qos = (flags >> 1) & 0x03
            guard let (topic, packetId, payload) = MqttClient.parsePublishBody(body, qos: qos) else {
                return
            }
            delegate?.mqttMessage(topic: topic, payload: payload)
            if qos == 1 {
                send(packet: MqttClient.buildPacket(type: MqttClient.PUBACK, flags: 0, body: Data([UInt8((packetId >> 8) & 0xff), UInt8(packetId & 0xff)])))
            }
        case MqttClient.SUBACK:
            subscribed = true
        case MqttClient.PINGRESP, MqttClient.PUBACK:
            break //nothing to do; PUBACK just acknowledges one of our QoS 1 publishes
        default:
            break
        }
    }

    // MARK: - Keep alive

    private func startKeepAlive() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler { [weak self] in
            guard let self = self, self.connected, !self.closing else {
                return
            }
            if CFAbsoluteTimeGetCurrent() - self.lastWrite >= Double(self.keepAliveSeconds) {
                self.send(packet: Data([UInt8(MqttClient.PINGREQ << 4), 0x00]))
            }
        }
        timer.resume()
        keepAliveTimer = timer
    }

    // MARK: - Writing (all on queue)

    private func send(packet: Data) {
        guard let connection = connection else {
            return
        }
        lastWrite = CFAbsoluteTimeGetCurrent()
        connection.send(content: packet, completion: .contentProcessed({ [weak self] error in
            guard let self = self, self.connection === connection else {
                return
            }
            if let error = error {
                self.connectionLost(reason: "write failed: \(error.localizedDescription)")
            }
        }))
    }

    private func nextPacketId() -> Int {
        packetIdCounter = packetIdCounter &+ 1
        if packetIdCounter == 0 { //packet identifier must be non-zero
            packetIdCounter = 1
        }
        return Int(packetIdCounter)
    }

    // MARK: - Packet builders and wire helpers (static, also used by the unit tests)

    static func buildConnectPacket(clientId: String, username: String?, password: String?, cleanSession: Bool, keepAliveSeconds: Int) -> Data {
        var body = Data()
        body.append(encodeString("MQTT"))   //protocol name
        body.append(0x04)                   //protocol level 4 = MQTT 3.1.1
        var flags: UInt8 = 0
        if username != nil { flags |= 0x80 }
        if password != nil { flags |= 0x40 }
        if cleanSession { flags |= 0x02 }
        body.append(flags)
        body.append(UInt8((keepAliveSeconds >> 8) & 0xff))
        body.append(UInt8(keepAliveSeconds & 0xff))
        body.append(encodeString(clientId))
        if let username = username {
            body.append(encodeString(username))
        }
        if let password = password {
            body.append(encodeString(password))
        }
        return buildPacket(type: CONNECT, flags: 0, body: body)
    }

    static func buildPublishPacket(topic: String, payload: Data, qos: Int, packetId: Int) -> Data {
        var body = Data()
        body.append(encodeString(topic))
        if qos > 0 {
            body.append(UInt8((packetId >> 8) & 0xff))
            body.append(UInt8(packetId & 0xff))
        }
        body.append(payload)
        return buildPacket(type: PUBLISH, flags: (qos & 0x03) << 1, body: body)
    }

    static func buildSubscribePacket(topic: String, qos: Int, packetId: Int) -> Data {
        var body = Data()
        body.append(UInt8((packetId >> 8) & 0xff))
        body.append(UInt8(packetId & 0xff))
        body.append(encodeString(topic))
        body.append(UInt8(qos & 0x03))
        return buildPacket(type: SUBSCRIBE, flags: 0x02, body: body) //SUBSCRIBE requires the reserved flags 0010
    }

    static func buildPacket(type: Int, flags: Int, body: Data) -> Data {
        var packet = Data()
        packet.append(UInt8((type << 4) | (flags & 0x0f)))
        packet.append(encodeRemainingLength(body.count))
        packet.append(body)
        return packet
    }

    static func encodeString(_ s: String) -> Data {
        let bytes = Data(s.utf8)
        var data = Data()
        data.append(UInt8((bytes.count >> 8) & 0xff))
        data.append(UInt8(bytes.count & 0xff))
        data.append(bytes)
        return data
    }

    static func encodeRemainingLength(_ length: Int) -> Data {
        var data = Data()
        var remaining = length
        repeat {
            var digit = UInt8(remaining & 0x7f)
            remaining >>= 7
            if remaining > 0 {
                digit |= 0x80
            }
            data.append(digit)
        } while remaining > 0
        return data
    }

    ///Decodes a variable-length Remaining Length from the start of data. Returns the value and the number of bytes consumed, or nil if incomplete or malformed.
    static func decodeRemainingLength(_ data: Data) -> (value: Int, bytesUsed: Int)? {
        var multiplier = 1, value = 0, count = 0
        for byte in data {
            value += Int(byte & 0x7f) * multiplier
            multiplier *= 128
            count += 1
            if count > 4 {
                return nil
            }
            if byte & 0x80 == 0 {
                return (value, count)
            }
        }
        return nil
    }

    static func parsePublishBody(_ body: Data, qos: Int) -> (topic: String, packetId: Int, payload: Data)? {
        var i = body.startIndex
        guard body.count >= 2 else {
            return nil
        }
        let topicLen = (Int(body[i]) << 8) | Int(body[i + 1])
        i += 2
        guard body.endIndex - i >= topicLen + (qos > 0 ? 2 : 0), let topic = String(data: body[i..<i+topicLen], encoding: .utf8) else {
            return nil
        }
        i += topicLen
        var packetId = -1
        if qos > 0 {
            packetId = (Int(body[i]) << 8) | Int(body[i + 1])
            i += 2
        }
        return (topic, packetId, Data(body[i...]))
    }

    static func connackMessage(_ returnCode: Int) -> String {
        switch returnCode {
        case 1: return "connection refused: unacceptable protocol version"
        case 2: return "connection refused: identifier rejected"
        case 3: return "connection refused: server unavailable"
        case 4: return "connection refused: bad username or password"
        case 5: return "connection refused: not authorized"
        default: return "connection refused: code \(returnCode)"
        }
    }
}
