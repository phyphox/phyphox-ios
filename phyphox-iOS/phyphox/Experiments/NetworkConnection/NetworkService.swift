//
//  NetworkService.swift
//  phyphox
//
//  Created by Sebastian Staacks on 27.11.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation

protocol NetworkService {
    func connect(address: String)
    func disconnect()
    func execute(send: [String: NetworkSendableData], requestCallbacks: [NetworkServiceRequestCallback])
    func getResults() -> [Data]?
}

protocol NetworkServiceRequestCallback {
    func requestFinished(result: NetworkServiceResult)
}

enum NetworkServiceResult: Equatable {
    case success
    case timeout
    case noConnection
    case conversionError(message: String)
    case genericError(message: String)
}

class HttpGetService: NetworkService {
    
    var address: String? = nil
    var data: Data?
    //A callback does not receive the response: it reads it back through getResults(), from this
    //one field shared by every request. The shared URLSession runs its completion handlers on a
    //serial queue, so two responses cannot interleave here the way they did on Android (store A,
    //store B, both callbacks read B - a poll parked twice and one lost, t1 network fixtures
    //2026-09-04). But execute() on the analysis thread clears the field for the next request, and
    //that can land between the store and the callback's read: the callback then parks an empty
    //response and the receive buffers are emptied on the next cycle. So storing the response and
    //running the callbacks is one step under this lock, and so is the clear. getResults() is
    //called from inside the locked callbacks and must not take the lock itself.
    private let resultLock = NSLock()
    
    func connect(address: String) {
        self.address = address
    }
    
    func disconnect() {
        address = nil
    }
    
    func execute(send: [String : NetworkSendableData], requestCallbacks: [NetworkServiceRequestCallback]) {
        guard let address = address else {
            requestCallbacks.forEach{$0.requestFinished(result: .noConnection)}
            return
        }
        resultLock.lock()
        data = nil
        resultLock.unlock()
        
        guard var url = URLComponents(string: address) else {
            requestCallbacks.forEach{$0.requestFinished(result: .genericError(message: "No valid URL: \(address)"))}
            return
        }
        
        var queryItems: [URLQueryItem] = url.queryItems ?? []
        for item in send.keys {
            switch send[item]?.source {
            case .Buffer(let buffer, keep: _):
                queryItems.append(URLQueryItem(name: item, value: String(buffer.last ?? Double.nan)))
            case .Metadata(let metadata):
                queryItems.append(URLQueryItem(name: item, value: metadata.get(hash: address)))
            case .Time:
                queryItems.append(URLQueryItem(name: item, value: "\(Date().timeIntervalSince1970)"))
            default:
                break
            }
        }
        url.queryItems = queryItems
        
        guard let finalUrl = url.url else {
            requestCallbacks.forEach{$0.requestFinished(result: .genericError(message: "No valid URL: \(url)"))}
            return
        }
        
        var request = URLRequest(url: finalUrl)
        request.httpMethod = "GET"

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                requestCallbacks.forEach{$0.requestFinished(result: .genericError(message: "Could not retrieve data. \(error?.localizedDescription ?? "No specific error message.")"))}
                return
            }
            
            guard let response = response as? HTTPURLResponse else {
                requestCallbacks.forEach{$0.requestFinished(result: .genericError(message: "Did not get a http response."))}
                return
            }
            
            guard 200 <= response.statusCode && 300 > response.statusCode else {
                requestCallbacks.forEach{$0.requestFinished(result: .genericError(message: "Http response code: \(response.statusCode)"))}
                return
            }
                
            self.resultLock.lock()
            self.data = data
            requestCallbacks.forEach{$0.requestFinished(result: .success)}
            self.resultLock.unlock()
        }
        task.resume()
    }
    
    func getResults() -> [Data]? {
        guard let data = data else {
            return []
        }
        return [data]
    }
}


class HttpPostService: NetworkService {
    
    var address: String? = nil
    var data: Data?
    //A callback does not receive the response: it reads it back through getResults(), from this
    //one field shared by every request. The shared URLSession runs its completion handlers on a
    //serial queue, so two responses cannot interleave here the way they did on Android (store A,
    //store B, both callbacks read B - a poll parked twice and one lost, t1 network fixtures
    //2026-09-04). But execute() on the analysis thread clears the field for the next request, and
    //that can land between the store and the callback's read: the callback then parks an empty
    //response and the receive buffers are emptied on the next cycle. So storing the response and
    //running the callbacks is one step under this lock, and so is the clear. getResults() is
    //called from inside the locked callbacks and must not take the lock itself.
    private let resultLock = NSLock()
    
    func connect(address: String) {
        self.address = address
    }
    
    func disconnect() {
        address = nil
    }
    
    func execute(send: [String : NetworkSendableData], requestCallbacks: [NetworkServiceRequestCallback]) {
        guard let address = address else {
            requestCallbacks.forEach{$0.requestFinished(result: .noConnection)}
            return
        }
        resultLock.lock()
        data = nil
        resultLock.unlock()
        
        guard let url = URL(string: address) else {
            requestCallbacks.forEach{$0.requestFinished(result: .genericError(message: "No valid URL: \(address)"))}
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if send.count > 0 {
            var json = [String:Any]()
            for item in send.keys {
                switch send[item]?.source {
                case .Buffer(let buffer, keep: _):
                    if send[item]?.additionalAttributes["datatype"] == "number" {
                        if let last = buffer.last {
                            json[item] = last.isFinite ? last as AnyObject : NSNull() as AnyObject
                        } else {
                            json[item] = NSNull() as AnyObject
                        }
                    } else {
                        json[item] = buffer.toArray().map({$0.isFinite ? $0 as AnyObject : NSNull() as AnyObject}) as AnyObject
                    }
                case .Metadata(let metadata):
                    json[item] = metadata.get(hash: address)
                case .Time(let timeReference):
                    var timeJson = [String:AnyObject]()
                    timeJson["now"] = Date().timeIntervalSince1970 as AnyObject
                    var eventsJson = [AnyObject]()
                    for mapping in timeReference.timeMappings {
                        var eventJson = [String:AnyObject]()
                        eventJson["event"] = mapping.event.rawValue as AnyObject
                        eventJson["experimentTime"] = mapping.experimentTime as AnyObject
                        eventJson["systemTime"] = mapping.systemTime.timeIntervalSince1970 as AnyObject
                        eventsJson.append(eventJson as AnyObject)
                    }
                    timeJson["events"] = eventsJson as AnyObject
                    json[item] = timeJson
                case .none: break
                }
            }
            
            guard let data = try? JSONSerialization.data(withJSONObject: json, options: []) else {
                requestCallbacks.forEach{$0.requestFinished(result: .genericError(message: "Could not create JSON."))}
                return
            }
            request.httpBody = data
        }
            
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                requestCallbacks.forEach{$0.requestFinished(result: .genericError(message: "Could not retrieve data. \(error?.localizedDescription ?? "No specific error message.")"))}
                return
            }
            
            guard let response = response as? HTTPURLResponse else {
                requestCallbacks.forEach{$0.requestFinished(result: .genericError(message: "Did not get a http response."))}
                return
            }
            
            guard 200 <= response.statusCode && 300 > response.statusCode else {
                requestCallbacks.forEach{$0.requestFinished(result: .genericError(message: "Http response code: \(response.statusCode)"))}
                return
            }
                
            self.resultLock.lock()
            self.data = data
            requestCallbacks.forEach{$0.requestFinished(result: .success)}
            self.resultLock.unlock()
        }
        task.resume()
    }
    
    func getResults() -> [Data]? {
        guard let data = data else {
            return []
        }
        return [data]
    }
}

/**
 Base class of the MQTT network services, driving the from-scratch `MqttClient` (MQTT 3.1.1, no
 external dependency - it replaced CocoaMQTT). The concrete subclasses only choose the payload
 format (JSON or CSV) and whether TLS and authentication are used, mirroring the class structure
 on Android (NetworkConnection/Mqtt/MqttService.java). See network-mqtts-unofficial in
 phyphox-docs.

 The former QoS-2 "persistence" mode is gone: persistence="true" now publishes with QoS 1
 (at-least-once) while connected, and there is no more offline message buffering. Plain publishes
 use QoS 0.
 */
class MqttService: MqttClientDelegate {
    //Configuration, set by the concrete subclasses before connect()
    var receiveTopic: String = ""
    var clientID: String = ""
    var username: String? = nil
    var password: String? = nil
    var tls = false
    var certificateFileName: String? = nil //resource name of a custom CA (see the certificate attribute); nil = system trust store
    var qos = 0
    weak var experiment: Experiment? = nil //resolves the certificate resource at connect time (set in Experiment.init)

    var address: String? = nil //as given in the experiment file, used as the salt for the per-broker metadata id
    var client: MqttClient? = nil
    private var connectionError: String? = nil
    private var data: [Data] = []
    private let dataLock = NSLock()

    //Resources this service needs from the experiment container, so the certificate is copied
    //along when the experiment is saved to the collection, like an image resource
    var resources: [String] {
        if let certificateFileName = certificateFileName, !certificateFileName.isEmpty {
            return [certificateFileName]
        }
        return []
    }

    func connect(address: String) {
        self.address = address
        connectionError = nil

        var customCACertificate: SecCertificate? = nil
        if tls, let certificateFileName = certificateFileName, !certificateFileName.isEmpty {
            //A named certificate that cannot be loaded is an error - silently falling back to the
            //system trust store would connect with a different trust model than the experiment
            //author intended
            guard let file = experiment?.resolveResource(certificateFileName), let certificate = MqttService.loadCertificate(from: file) else {
                connectionError = "Certificate \"\(certificateFileName)\" could not be loaded."
                return
            }
            customCACertificate = certificate
        }

        //Parse host and port out of the address, which may carry a scheme prefix
        var hostPort = address
        if let schemeRange = hostPort.range(of: "://") {
            hostPort = String(hostPort[schemeRange.upperBound...])
        }
        let host: String
        let port: UInt16
        let defaultPort: UInt16 = tls ? 8883 : 1883
        if let colon = hostPort.range(of: ":", options: .backwards) {
            host = String(hostPort[..<colon.lowerBound])
            port = UInt16(hostPort[colon.upperBound...]) ?? defaultPort
        } else {
            host = hostPort
            port = defaultPort
        }

        let client = MqttClient(host: host, port: port, clientId: clientID, username: username, password: password, cleanSession: true, keepAliveSeconds: 60, tls: tls ? MqttClient.TLSConfig(customCACertificate: customCACertificate) : nil, subscribeTopic: receiveTopic, delegate: self)
        self.client = client
        client.connect()
    }

    func disconnect() {
        client?.disconnect()
        client = nil
    }

    func mqttMessage(topic: String, payload: Data) {
        dataLock.lock()
        defer { dataLock.unlock() }
        data.append(payload)
    }

    func mqttConnected() {
        connectionError = nil
    }

    func mqttConnectionLost(reason: String) {
        print("MQTT connection lost: \(reason)")
        connectionError = reason
    }

    func getResults() -> [Data]? {
        dataLock.lock()
        defer { dataLock.unlock() }
        let result = data
        data = []
        return result
    }

    func getState() -> NetworkServiceResult {
        if !(client?.connected ?? false) {
            //The client reconnects on its own with exponential backoff; here we only report.
            //Keeping the last error gives the user a descriptive message (e.g. the CONNACK
            //return code) instead of a generic "no connection".
            if let connectionError = connectionError {
                return NetworkServiceResult.genericError(message: "MQTT: \(connectionError)")
            }
            return NetworkServiceResult.noConnection
        }
        if !(client?.subscribed ?? false) && !receiveTopic.isEmpty {
            return NetworkServiceResult.genericError(message: "Not subscribed.")
        }
        return NetworkServiceResult.success
    }

    func publish(topic: String, payload: String) {
        client?.publish(topic: topic, payload: Data(payload.utf8), qos: qos)
    }

    //Loads a CA certificate in PEM or DER form (.pem/.crt/.cer/.der)
    static func loadCertificate(from url: URL) -> SecCertificate? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        if let certificate = SecCertificateCreateWithData(nil, data as CFData) {
            return certificate //DER
        }
        //PEM: extract the first CERTIFICATE block and decode its base64 payload
        guard let text = String(data: data, encoding: .utf8),
              let beginRange = text.range(of: "-----BEGIN CERTIFICATE-----"),
              let endRange = text.range(of: "-----END CERTIFICATE-----"),
              beginRange.upperBound <= endRange.lowerBound else {
            return nil
        }
        let base64 = text[beginRange.upperBound..<endRange.lowerBound].components(separatedBy: .whitespacesAndNewlines).joined()
        guard let der = Data(base64Encoded: base64) else {
            return nil
        }
        return SecCertificateCreateWithData(nil, der as CFData)
    }
}

class MqttCsvService: MqttService, NetworkService {
    init(receiveTopic: String, username: String?, password: String?) {
        super.init()
        self.receiveTopic = receiveTopic
        self.username = username //optional: nil connects without authentication
        self.password = password
        self.clientID = "phyphox_" + String(format: "%06x", Int(CFAbsoluteTimeGetCurrent()*1e9) & 0xffffff)
    }

    func execute(send: [String : NetworkSendableData], requestCallbacks: [NetworkServiceRequestCallback]) {
        let state = getState()
        if state != .success {
            requestCallbacks.forEach{$0.requestFinished(result: state)}
            return
        }
        
        for item in send.keys {
            let payload: String
            switch send[item]?.source {
            case .Buffer(let buffer, keep: _):
                if send[item]?.additionalAttributes["datatype"] == "number" {
                    if let last = buffer.last {
                        payload = last.isFinite ? String(last) : "null"
                    } else {
                        continue
                    }
                } else {
                    payload = buffer.toArray().map({$0.isFinite ? String($0) : "null"}).joined(separator: ",")
                }
            case .Metadata(let metadata):
                guard let address = address else {
                    //This should be impossible. However, if it happens, the unique ID might be the same across different services, which we can not have. So...
                    continue
                }
                payload = metadata.get(hash: address) ?? "null"
            case .Time(_):
                payload = "\(Date().timeIntervalSince1970)"
            case .none: continue
            }
            publish(topic: item, payload: payload)
        }

        requestCallbacks.forEach{$0.requestFinished(result: .success)}
    }
}

class MqttJsonService: MqttService, NetworkService {
    let sendTopic: String

    init(receiveTopic: String, sendTopic: String, username: String?, password: String?, persistence: Bool) {
        self.sendTopic = sendTopic
        super.init()
        self.receiveTopic = receiveTopic
        self.username = username //optional: nil connects without authentication
        self.password = password
        self.clientID = "phyphox_" + String(format: "%06x", Int(CFAbsoluteTimeGetCurrent()*1e9) & 0xffffff)
        //persistence now selects at-least-once delivery (QoS 1) instead of the former QoS 2
        self.qos = persistence ? 1 : 0
    }

    func execute(send: [String : NetworkSendableData], requestCallbacks: [NetworkServiceRequestCallback]) {
        let state = getState()
        if state != .success {
            requestCallbacks.forEach{$0.requestFinished(result: state)}
            return
        }
        
        var json = [String:Any]()
        for item in send.keys {
            switch send[item]?.source {
            case .Buffer(let buffer, keep: _):
                if send[item]?.additionalAttributes["datatype"] == "number" {
                    if let last = buffer.last {
                        json[item] = last.isFinite ? last as AnyObject : NSNull() as AnyObject
                    } else {
                        json[item] = NSNull() as AnyObject
                    }
                } else {
                    json[item] = buffer.toArray().map({$0.isFinite ? $0 as AnyObject : NSNull() as AnyObject}) as AnyObject
                }
            case .Metadata(let metadata):
                guard let address = address else {
                    //This should be impossible. However, if it happens, the unique ID might be the same across different services, which we can not have. So...
                    continue
                }
                json[item] = metadata.get(hash: address)
            case .Time(let timeReference):
                var timeJson = [String:AnyObject]()
                timeJson["now"] = Date().timeIntervalSince1970 as AnyObject
                var eventsJson = [AnyObject]()
                for mapping in timeReference.timeMappings {
                    var eventJson = [String:AnyObject]()
                    eventJson["event"] = mapping.event.rawValue as AnyObject
                    eventJson["experimentTime"] = mapping.experimentTime as AnyObject
                    eventJson["systemTime"] = mapping.systemTime.timeIntervalSince1970 as AnyObject
                    eventsJson.append(eventJson as AnyObject)
                }
                timeJson["events"] = eventsJson as AnyObject
                json[item] = timeJson
            case .none: break
            }
        }
        
        guard let jsondata = try? JSONSerialization.data(withJSONObject: json, options: []) else {
            requestCallbacks.forEach{$0.requestFinished(result: .genericError(message: "Could not create JSON."))}
            return
        }
        
        let jsonstring = String(data: jsondata, encoding: .utf8)
        guard let payload = jsonstring else {
            requestCallbacks.forEach{$0.requestFinished(result: .genericError(message: "Could not encode JSON."))}
            return
        }

        publish(topic: sendTopic, payload: payload)

        requestCallbacks.forEach{$0.requestFinished(result: .success)}
    }
}

class MqttTlsCsvService: MqttCsvService {
    init(receiveTopic: String, username: String, password: String, certificateFileName: String?) {
        super.init(receiveTopic: receiveTopic, username: username, password: password)
        self.tls = true
        self.clientID = username //the mqtts services use the username as the client id, like Android
        self.certificateFileName = certificateFileName //optional: nil uses the system trust store
    }
}

class MqttTlsJsonService: MqttJsonService {
    init(receiveTopic: String, sendTopic: String, username: String, password: String, certificateFileName: String?, persistence: Bool) {
        super.init(receiveTopic: receiveTopic, sendTopic: sendTopic, username: username, password: password, persistence: persistence)
        self.tls = true
        self.clientID = username //the mqtts services use the username as the client id, like Android
        self.certificateFileName = certificateFileName //optional: nil uses the system trust store
    }
}

