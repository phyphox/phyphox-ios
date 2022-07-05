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

enum ExperimentAnalysisDataIO: Equatable {
    case buffer(buffer: DataBuffer, data: MutableDoubleArray, usedAs: String, clear: Bool)
    case value(value: Double, usedAs: String)

    func getSingleValue() -> Double? {
        switch self {
        case .buffer(buffer: _, data: let data, usedAs: _, clear: _):
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
        case .buffer(buffer: _, data: _, usedAs: let usedAs, clear: _):
            return usedAs
        case .value(value: _, usedAs: let usedAs):
            return usedAs
        }
    }

    var isBuffer: Bool {
        switch self {
        case .buffer(buffer: _, data: _, usedAs: _, clear: _):
            return true
        case .value(value: _, usedAs: _):
            return false
        }
    }
    
    func retainData() {
        switch self {
        case .buffer(buffer: let buffer, data: let data, usedAs: _, clear: _):
            data.data = buffer.toArray()
            return
        case .value(value: _, usedAs: _):
            return
        }
    }
    
    func clear() {
        switch self {
        case .buffer(buffer: let buffer, data: _, usedAs: _, clear: let clear):
            if clear && !buffer.staticBuffer && !buffer.attachedToTextField {
                buffer.clear(reset: false)
            }
            return
        case .value(value: _, usedAs: _):
            return
        }
    }
}
