//
//  NetworkConversion.swift
//  phyphox
//
//  Created by Sebastian Staacks on 27.11.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation

protocol NetworkConversion {
    func prepare(data: [Data]) throws
    func get(_ id: String) throws -> [Double]
}

enum NetworkConversionError: Error {
    case genericError(message: String)
    case invalidInput(message: String)
    case emptyInput
    case notImplemented
}

class NoneNetworkConversion: NetworkConversion {

    func prepare(data: [Data]) throws {
    }
    
    func get(_ id: String) throws -> [Double] {
        return []
    }
}

class CSVNetworkConversion: NetworkConversion {
    var data: [String?] = []
    
    func prepare(data: [Data]) throws {
        self.data = data.map{String(data: $0, encoding: .utf8)}
    }
    
    func get(_ id: String) throws -> [Double] {
        var result: [Double] = []
        let index = Int(id) ?? -1
        
        for subdata in data {
            guard let set = subdata else {
                continue
            }
            let lines = set.components(separatedBy: "\n")
            for line in lines {
                let columns = line.components(separatedBy: CharacterSet(charactersIn: ",;"))
                if index < 0 {
                    for column in columns {
                        result.append(Double(column.trimmingCharacters(in: .whitespacesAndNewlines)) ?? Double.nan)
                    }
                } else if columns.count > index {
                    result.append(Double(columns[index].trimmingCharacters(in: .whitespacesAndNewlines)) ?? Double.nan)
                }
            }
        }
        return result
    }
}

class JSONNetworkConversion: NetworkConversion {

    var json: [[String: Any]] = []
    
    func prepare(data: [Data]) throws {
        json = []
        for set in data {
            let serialized = try? JSONSerialization.jsonObject(with: set, options: [])
            guard let serializedJSON = serialized else {
                throw NetworkConversionError.invalidInput(message: "Could not parse JSON.")
            }
            
            let jsoncast = serializedJSON as? [String: Any]
            
            guard let json = jsoncast else {
                throw NetworkConversionError.invalidInput(message: "No JSON object.")
            }
            
            self.json.append(json)
        }
    }
    
    func get(_ id: String) throws -> [Double] {
        let components = id.components(separatedBy: ".")
        var result: [Double] = []
        for set in json {
            var currentJSON: Any = set as Any
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
                result.append(contentsOf: values)
                continue
            }
            if let value = currentJSON as? Double {
                result.append(value)
                continue
            }
            throw NetworkConversionError.genericError(message: "\(id) is not a number or a numerical array.")
        }
        return result
    }
}
