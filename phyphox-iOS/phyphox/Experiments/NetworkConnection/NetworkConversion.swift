//
//  NetworkConversion.swift
//  phyphox
//
//  Created by Sebastian Staacks on 27.11.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation

protocol NetworkConversion {
    func prepare(data: Data) throws
    func get(_ id: String) throws -> [Double]
}

enum NetworkConversionError: Error {
    case genericError(message: String)
    case invalidInput(message: String)
    case emptyInput
    case notImplemented
}

class JSONNetworkConversion: NetworkConversion {

    var json: [String: Any]? = nil
    
    func prepare(data: Data) throws {
        if data.count == 0 {
            throw NetworkConversionError.emptyInput
        }
        
        let serialized = try? JSONSerialization.jsonObject(with: data, options: [])
        guard let serializedJSON = serialized else {
            throw NetworkConversionError.invalidInput(message: "Could not parse JSON.")
        }
        
        json = serializedJSON as? [String: Any]
        
        guard json != nil else {
            throw NetworkConversionError.invalidInput(message: "No JSON object.")
        }
    }
    
    func get(_ id: String) throws -> [Double] {
        let components = id.components(separatedBy: ".")
        var currentJSON: Any = json as Any
        for component in components {
            guard let currentDict = currentJSON as? [String: Any] else {
                throw NetworkConversionError.genericError(message: "Could not find \(id). (No object)")
            }
            guard let nextJSON = currentDict[component] else {
                throw NetworkConversionError.genericError(message: "Could not find \(id). (Not found)")
            }
            currentJSON = nextJSON
        }
        if let values = currentJSON as? [Double] {
            return values
        }
        if let value = currentJSON as? Double {
            return [value]
        }
        throw NetworkConversionError.genericError(message: "\(id) is not a number or a numerical array.")
    }
}
