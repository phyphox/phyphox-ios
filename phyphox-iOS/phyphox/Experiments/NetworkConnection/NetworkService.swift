//
//  NetworkService.swift
//  phyphox
//
//  Created by Sebastian Staacks on 27.11.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation
import CocoaMQTT

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
        data = nil
        
        guard var url = URLComponents(string: address) else {
            requestCallbacks.forEach{$0.requestFinished(result: .genericError(message: "No valid URL: \(address)"))}
            return
        }
        
        var queryItems: [URLQueryItem] = url.queryItems ?? []
        for item in send.keys {
            switch send[item]?.source {
            case .Buffer(let buffer):
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
                
            self.data = data
            requestCallbacks.forEach{$0.requestFinished(result: .success)}
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
        data = nil
        
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
                case .Buffer(let buffer):
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
                
            self.data = data
            requestCallbacks.forEach{$0.requestFinished(result: .success)}
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

class MqttService: CocoaMQTTDelegate {
    var address: String = ""
    var mqtt: CocoaMQTT? = nil
    var receiveTopic: String? = nil
    var connected = false
    var subscribed = false
    var data: [Data] = []
    
    func connect(address: String, receiveTopic: String?) {
        self.address = address
        self.receiveTopic = receiveTopic
        
        let clientID = "phyphox_" + String(Int64(CFAbsoluteTimeGetCurrent()*1e9) & 0xffffff)
        let addressParts = address.components(separatedBy: ":")
        let host = addressParts[0]
        let port: UInt16
        if addressParts.count > 1 {
            port = UInt16(addressParts[1]) ?? 1883
        } else {
            port = 1883
        }
        mqtt = CocoaMQTT(clientID: clientID, host: host, port: port)
        mqtt?.username = ""
        mqtt?.password = ""
        mqtt?.keepAlive = 60
        mqtt?.delegate = self
        _ = mqtt?.connect()
    }
    
    func disconnect() {
        mqtt?.disconnect()
        mqtt = nil
        connected = false
        subscribed = false
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        if ack == .accept {
            connected = true
            guard let receiveTopic = receiveTopic else {
                return
            }
            mqtt.subscribe(receiveTopic, qos: CocoaMQTTQoS.qos0)
        } else {
            connected = false
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        if success[receiveTopic ?? ""] != nil {
            subscribed = true
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        data.append(Data(message.payload))
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didStateChangeTo state: CocoaMQTTConnState) {
        print("MQTT connection to \(address) changed to \(state).")
        if state != .connected {
            connected = false
            subscribed = false
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        return
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        return
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
        return
    }
    
    func mqttDidPing(_ mqtt: CocoaMQTT) {
        return
    }
    
    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        return
    }
    
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        return
    }
    
    func getResults() -> [Data]? {
        let result = data
        data = []
        return result
    }
    
    func getState() -> NetworkServiceResult {
        if !connected {
            return NetworkServiceResult.noConnection
        }
        if !subscribed && receiveTopic != nil {
            return NetworkServiceResult.genericError(message: "Not subscribed.")
        }
        return NetworkServiceResult.success
    }
    
    func publish(topic: String, payload: String) {
        mqtt?.publish(topic, withString: payload, qos: .qos0)
    }
}

class MqttCsvService: NetworkService {
    var address: String? = nil
    let mqttService = MqttService()
    let receiveTopic: String?
    
    init(receiveTopic: String?) {
        self.receiveTopic = receiveTopic
    }
    
    func connect(address: String) {
        self.address = address
        mqttService.connect(address: address, receiveTopic: receiveTopic)
    }
    
    func disconnect() {
        mqttService.disconnect()
    }
    
    func execute(send: [String : NetworkSendableData], requestCallbacks: [NetworkServiceRequestCallback]) {
        let state = mqttService.getState()
        if state != .success {
            requestCallbacks.forEach{$0.requestFinished(result: state)}
            return
        }
        
        for item in send.keys {
            let payload: String
            switch send[item]?.source {
            case .Buffer(let buffer):
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
            mqttService.publish(topic: item, payload: payload)
        }
        
        requestCallbacks.forEach{$0.requestFinished(result: .success)}
    }
    
    func getResults() -> [Data]? {
        return mqttService.getResults()
    }
}

class MqttJsonService: NetworkService {
    var address: String? = nil
    let mqttService = MqttService()
    let receiveTopic: String?
    let sendTopic: String
    
    init(receiveTopic: String?, sendTopic: String) {
        self.receiveTopic = receiveTopic
        self.sendTopic = sendTopic
    }
    
    func connect(address: String) {
        self.address = address
        mqttService.connect(address: address, receiveTopic: receiveTopic)
    }
    
    func disconnect() {
        mqttService.disconnect()
    }
    
    func execute(send: [String : NetworkSendableData], requestCallbacks: [NetworkServiceRequestCallback]) {
        let state = mqttService.getState()
        if state != .success {
            requestCallbacks.forEach{$0.requestFinished(result: state)}
            return
        }
        
        var json = [String:Any]()
        for item in send.keys {
            switch send[item]?.source {
            case .Buffer(let buffer):
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
            
        mqttService.publish(topic: sendTopic, payload: payload)
        
        requestCallbacks.forEach{$0.requestFinished(result: .success)}
    }
    
    func getResults() -> [Data]? {
        return mqttService.getResults()
    }
}

