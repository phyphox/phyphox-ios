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

    //A value input acts as a one-element buffer, matching Android's DataInput.getArray()
    func getArray() -> [Double] {
        switch self {
        case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
            return data.data
        case .value(value: let value, usedAs: _):
            return [value]
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

    ///Compares the "as" name from the experiment file with a canonical slot name, folding case
    ///(enum-case-insensitive rule in phyphox-docs, matching Android)
    func used(as name: String) -> Bool {
        return asString.lowercased() == name.lowercased()
    }

    var isBuffer: Bool {
        switch self {
        case .buffer(buffer: _, data: _, usedAs: _, keep: _):
            return true
        case .value(value: _, usedAs: _):
            return false
        }
    }

    var dataBuffer: DataBuffer? {
        switch self {
        case .buffer(buffer: let buffer, data: _, usedAs: _, keep: _):
            return buffer
        case .value(value: _, usedAs: _):
            return nil
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
            //Buffers bound to interactive view elements are NOT exempt from clearing: the
            //element re-initializes its buffer to the default value instead (matching Android)
            if !keep && !buffer.staticBuffer {
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

    ///Compares the "as" name from the experiment file with a canonical slot name, folding case
    ///(enum-case-insensitive rule in phyphox-docs, matching Android)
    func used(as name: String) -> Bool {
        return asString.lowercased() == name.lowercased()
    }

    var isBuffer: Bool {
        switch self {
        case .buffer(buffer: _, data: _, usedAs: _, append: _):
            return true
        }
    }

    var dataBuffer: DataBuffer {
        switch self {
        case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
            return buffer
        }
    }

    var isStatic: Bool {
        return dataBuffer.staticBuffer
    }

    //Declares the module's write into this output complete, which locks a static buffer even if
    //the module wrote nothing (Android: DataOutput.markSet)
    func markSet() {
        dataBuffer.markSet()
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
            if !append && !buffer.staticBuffer {
                buffer.clear(reset: false)
            }
            return
        }
    }
}
