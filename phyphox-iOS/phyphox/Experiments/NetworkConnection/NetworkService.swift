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
    func getResults() -> Data?
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
            switch send[item] {
            case .Buffer(let buffer):
                queryItems.append(URLQueryItem(name: item, value: String(buffer.last ?? Double.nan)))
            case .Metadata(let metadata):
                queryItems.append(URLQueryItem(name: item, value: metadata.get(hash: address)))
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
    
    func getResults() -> Data? {
        return data
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
                switch send[item] {
                case .Buffer(let buffer):
                    json[item] = buffer.toArray().map({$0.isFinite ? $0 as AnyObject : NSNull() as AnyObject}) as AnyObject
                case .Metadata(let metadata):
                    json[item] = metadata.get(hash: address)
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
    
    func getResults() -> Data? {
        return data
    }
}
