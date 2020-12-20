//
//  OutputConversion.swift
//  phyphox
//
//  Created by Sebastian Staacks on 24.05.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation

protocol OutputConversion {
    func convert(data: DataBuffer) -> Data?
}

class ByteArrayOutputConversion: OutputConversion {
    init() {
    }
    
    func convert(data: DataBuffer) -> Data? {
        let array = data.toArray()
        var out = Data(capacity: array.count)
        for value in array {
            out.append(UInt8(value))
        }
        return out
    }
}

class SimpleOutputConversion: OutputConversion {
    enum ConversionFunction: String, LosslessStringConvertible {
        case string
        case uInt8
        case int8
        case uInt16LittleEndian
        case int16LittleEndian
        case uInt16BigEndian
        case int16BigEndian
        case uInt24LittleEndian
        case int24LittleEndian
        case uInt24BigEndian
        case int24BigEndian
        case uInt32LittleEndian
        case int32LittleEndian
        case uInt32BigEndian
        case int32BigEndian
        case float32LittleEndian
        case float32BigEndian
        case float64LittleEndian
        case float64BigEndian
    }
    
    let function: ConversionFunction

    init(function: ConversionFunction) {
        self.function = function
    }
    
    func convert(data: DataBuffer) -> Data? {
        guard let value = data.last else {
            return nil
        }
        switch function {
        case .string:
            return "\(value)".data(using: .utf8)
        case .uInt8:
            var mutable = UInt8(value)
            return Data(bytes: &mutable, count: MemoryLayout.size(ofValue: mutable))
        case .int8:
            var mutable = Int8(value)
            return Data(bytes: &mutable, count: MemoryLayout.size(ofValue: mutable))
        case .uInt16LittleEndian:
            var mutable = UInt16(value)
            return Data(bytes: &mutable, count: MemoryLayout.size(ofValue: mutable))
        case .int16LittleEndian:
            var mutable = Int16(value)
            return Data(bytes: &mutable, count: MemoryLayout.size(ofValue: mutable))
        case .uInt16BigEndian:
            var mutable = UInt16(value)
            let leData = Data(bytes: &mutable, count: MemoryLayout.size(ofValue: mutable))
            var data = Data(capacity: MemoryLayout.size(ofValue: mutable))
            for byte in leData.subdata(in: (0..<MemoryLayout.size(ofValue: mutable))).reversed() {
                data.append(byte)
            }
            return data
        case .int16BigEndian:
            var mutable = Int16(value)
            let leData = Data(bytes: &mutable, count: MemoryLayout.size(ofValue: mutable))
            var data = Data(capacity: MemoryLayout.size(ofValue: mutable))
            for byte in leData.subdata(in: (0..<MemoryLayout.size(ofValue: mutable))).reversed() {
                data.append(byte)
            }
            return data
        case .uInt24LittleEndian:
            var mutable = UInt32(value)
            let leData = Data(bytes: &mutable, count: MemoryLayout.size(ofValue: mutable))
            return leData.subdata(in: (1..<MemoryLayout.size(ofValue: mutable)))
        case .int24LittleEndian:
            var mutable = Int32(value)
            let leData = Data(bytes: &mutable, count: MemoryLayout.size(ofValue: mutable))
            return leData.subdata(in: (1..<MemoryLayout.size(ofValue: mutable)))
        case .uInt24BigEndian:
            var mutable = UInt32(value)
            let leData = Data(bytes: &mutable, count: MemoryLayout.size(ofValue: mutable))
            var data = Data(capacity: MemoryLayout.size(ofValue: mutable))
            for byte in leData.subdata(in: (1..<MemoryLayout.size(ofValue: mutable))).reversed() {
                data.append(byte)
            }
            return data
        case .int24BigEndian:
            var mutable = Int32(value)
            let leData = Data(bytes: &mutable, count: MemoryLayout.size(ofValue: mutable))
            var data = Data(capacity: MemoryLayout.size(ofValue: mutable))
            for byte in leData.subdata(in: (1..<MemoryLayout.size(ofValue: mutable))).reversed() {
                data.append(byte)
            }
            return data
        case .uInt32LittleEndian:
            var mutable = UInt32(value)
            return Data(bytes: &mutable, count: MemoryLayout.size(ofValue: mutable))
        case .int32LittleEndian:
            var mutable = Int32(value)
            return Data(bytes: &mutable, count: MemoryLayout.size(ofValue: mutable))
        case .uInt32BigEndian:
            var mutable = UInt32(value)
            let leData = Data(bytes: &mutable, count: MemoryLayout.size(ofValue: mutable))
            var data = Data(capacity: MemoryLayout.size(ofValue: mutable))
            for byte in leData.subdata(in: (0..<MemoryLayout.size(ofValue: mutable))).reversed() {
                data.append(byte)
            }
            return data
        case .int32BigEndian:
            var mutable = Int32(value)
            let leData = Data(bytes: &mutable, count: MemoryLayout.size(ofValue: mutable))
            var data = Data(capacity: MemoryLayout.size(ofValue: mutable))
            for byte in leData.subdata(in: (0..<MemoryLayout.size(ofValue: mutable))).reversed() {
                data.append(byte)
            }
            return data
        case .float32LittleEndian:
            var mutable = Float32(value)
            return Data(bytes: &mutable, count: MemoryLayout.size(ofValue: mutable))
        case .float32BigEndian:
            var mutable = Float32(value)
            let leData = Data(bytes: &mutable, count: MemoryLayout.size(ofValue: mutable))
            var data = Data(capacity: MemoryLayout.size(ofValue: mutable))
            for byte in leData.subdata(in: (0..<MemoryLayout.size(ofValue: mutable))).reversed() {
                data.append(byte)
            }
            return data
        case .float64LittleEndian:
            var mutable = Float64(value)
            return Data(bytes: &mutable, count: MemoryLayout.size(ofValue: mutable))
        case .float64BigEndian:
            var mutable = Float64(value)
            let leData = Data(bytes: &mutable, count: MemoryLayout.size(ofValue: mutable))
            var data = Data(capacity: MemoryLayout.size(ofValue: mutable))
            for byte in leData.subdata(in: (0..<MemoryLayout.size(ofValue: mutable))).reversed() {
                data.append(byte)
            }
            return data
        }
    }
}

