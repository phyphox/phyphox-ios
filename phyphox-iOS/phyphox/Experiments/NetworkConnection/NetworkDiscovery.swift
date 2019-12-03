//
//  NetworkDiscovery.swift
//  phyphox
//
//  Created by Sebastian Staacks on 27.11.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation

protocol NetworkDiscovery {
    func startDiscovery(onNewResult: NetworkDiscoveryCallback)
    func stopDiscovery()
}

protocol NetworkDiscoveryCallback {
    func newItem(name: String?, address: String)
}

class HttpNetworkDiscovery : NetworkDiscovery {
    var task: URLSessionTask? = nil
    let address: String
    
    init(address: String) {
        self.address = address
    }
    
    func startDiscovery(onNewResult: NetworkDiscoveryCallback) {
        guard let url = URL(string: address) else {
            return
        }

        task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data, error == nil else {
                return
            }

            guard let response = response as? HTTPURLResponse else {
                return
            }
            
            guard 200 <= response.statusCode && 300 > response.statusCode else {
                return
            }
            
            onNewResult.newItem(name: String(data: data.prefix(50), encoding: .utf8), address: self.address)
            self.stopDiscovery()
        }
        task?.resume()
    }
    
    func stopDiscovery() {
        task?.cancel()
        task = nil
    }
}

