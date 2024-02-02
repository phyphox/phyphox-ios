//
//  ExperimentAnalysisDataIO.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

class MutableDoubleArray: Equatable {
    static func == (lhs: MutableDoubleArray, rhs: MutableDoubleArray) -> Bool {
        lhs.data == rhs.data
    }
    
    var data: [Double]
    
    init(data: [Double]) {
        self.data = data
    }
}

enum ExperimentAnalysisDataInput: Equatable {
    case buffer(buffer: DataBuffer, data: MutableDoubleArray, usedAs: String, keep: Bool)
    case value(value: Double, usedAs: String)

    func getSingleValue() -> Double? {
        switch self {
        case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
            return data.data.last
        case .value(value: let value, usedAs: _):
            return value
        }
    }
    
    func getSingleValueAsInt() -> Int? {
        if let d = getSingleValue() {
            if d > Double(Int.min) && d < Double(Int.max) {
                return Int(d)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }

    var asString: String {
        switch self {
        case .buffer(buffer: _, data: _, usedAs: let usedAs, keep: _):
            return usedAs
        case .value(value: _, usedAs: let usedAs):
            return usedAs
        }
    }

    var isBuffer: Bool {
        switch self {
        case .buffer(buffer: _, data: _, usedAs: _, keep: _):
            return true
        case .value(value: _, usedAs: _):
            return false
        }
    }
    
    func retainData() {
        switch self {
        case .buffer(buffer: let buffer, data: let data, usedAs: _, keep: _):
            data.data = buffer.toArray()
            return
        case .value(value: _, usedAs: _):
            return
        }
    }
    
    func clear() {
        switch self {
        case .buffer(buffer: let buffer, data: _, usedAs: _, keep: let keep):
            if !keep && !buffer.staticBuffer && !buffer.attachedToTextField {
                buffer.clear(reset: false)
            }
            return
        case .value(value: _, usedAs: _):
            return
        }
    }
}

enum ExperimentAnalysisDataOutput: Equatable {
    case buffer(buffer: DataBuffer, data: MutableDoubleArray, usedAs: String, append: Bool)

    func getSingleValue() -> Double? {
        switch self {
        case .buffer(buffer: _, data: let data, usedAs: _, append: _):
            return data.data.last
        }
    }
    
    func getSingleValueAsInt() -> Int? {
        if let d = getSingleValue() {
            if d > Double(Int.min) && d < Double(Int.max) {
                return Int(d)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }

    var asString: String {
        switch self {
        case .buffer(buffer: _, data: _, usedAs: let usedAs, append: _):
            return usedAs
        }
    }

    var isBuffer: Bool {
        switch self {
        case .buffer(buffer: _, data: _, usedAs: _, append: _):
            return true
        }
    }
    
    func retainData() {
        switch self {
        case .buffer(buffer: let buffer, data: let data, usedAs: _, append: _):
            data.data = buffer.toArray()
            return
        }
    }
    
    func clear() {
        switch self {
        case .buffer(buffer: let buffer, data: _, usedAs: _, append: let append):
            if !append && !buffer.staticBuffer && !buffer.attachedToTextField {
                buffer.clear(reset: false)
            }
            return
        }
    }
}
