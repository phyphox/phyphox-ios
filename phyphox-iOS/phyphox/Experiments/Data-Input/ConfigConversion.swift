//
//  ConfigConversion.swift
//  phyphox
//
//  Created by Sebastian Staacks on 21.05.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation

protocol ConfigConversion {
    func convert(data: String) -> Data
}

class SimpleConfigConversion: ConfigConversion {
    enum ConversionFunction: String, LosslessStringConvertible {
        case string
        case hexadecimal
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
    
    func convert(data: String) -> Data {
        switch function {
        case .string:
            return data.data(using: .utf8) ?? Data()
        case .hexadecimal:
            let hexString = data.replacingOccurrences(of: " ", with: "")
            var result = Data(capacity: hexString.count / 2)
            var index = hexString.startIndex
            while index < hexString.endIndex {
                let pair = hexString[index...hexString.index(after: index)]
                if let num = UInt8(pair, radix: 16) {
                    result.append(num)
                } else {
                    return Data()
                }
                index = hexString.index(after: hexString.index(after: index))
            }
            
            guard result.count > 0 else { return Data() }
            return result
        case .uInt8:
            var value = UInt8(data)
            return Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
        case .int8:
            var value = Int8(data)
            return Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
        case .uInt16LittleEndian:
            var value = UInt16(data)
            return Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
        case .int16LittleEndian:
            var value = Int16(data)
            return Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
        case .uInt16BigEndian:
            var value = UInt16(data)
            let leData = Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
            var data = Data(capacity: MemoryLayout.size(ofValue: value))
            for byte in leData.reversed() {
                data.append(byte)
            }
            return data
        case .int16BigEndian:
            var value = Int16(data)
            let leData = Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
            var data = Data(capacity: MemoryLayout.size(ofValue: value))
            for byte in leData.reversed() {
                data.append(byte)
            }
            return data
        case .uInt24LittleEndian:
            var value = UInt32(data)
            let uInt32 = Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
            return uInt32.subdata(in: (1..<MemoryLayout.size(ofValue: value)))
        case .int24LittleEndian:
            var value = Int32(data)
            let Int32 = Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
            return Int32.subdata(in: (1..<MemoryLayout.size(ofValue: value)))
        case .uInt24BigEndian:
            var value = UInt32(data)
            let leData = Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
            var data = Data(capacity: MemoryLayout.size(ofValue: value)-1)
            for byte in leData.subdata(in: (1..<MemoryLayout.size(ofValue: value))).reversed() {
                data.append(byte)
            }
            return data
        case .int24BigEndian:
            var value = Int32(data)
            let leData = Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
            var data = Data(capacity: MemoryLayout.size(ofValue: value)-1)
            for byte in leData.subdata(in: (1..<MemoryLayout.size(ofValue: value))).reversed() {
                data.append(byte)
            }
            return data
        case .uInt32LittleEndian:
            var value = UInt32(data)
            return Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
        case .int32LittleEndian:
            var value = Int32(data)
            return Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
        case .uInt32BigEndian:
            var value = UInt32(data)
            let leData = Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
            var data = Data(capacity: MemoryLayout.size(ofValue: value))
            for byte in leData.reversed() {
                data.append(byte)
            }
            return data
        case .int32BigEndian:
            var value = Int32(data)
            let leData = Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
            var data = Data(capacity: MemoryLayout.size(ofValue: value))
            for byte in leData.reversed() {
                data.append(byte)
            }
            return data
        case .float32LittleEndian:
            var value = Float32(data)
            return Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
        case .float32BigEndian:
            var value = Float32(data)
            let leData = Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
            var data = Data(capacity: MemoryLayout.size(ofValue: value))
            for byte in leData.reversed() {
                data.append(byte)
            }
            return data
        case .float64LittleEndian:
            var value = Float64(data)
            return Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
        case .float64BigEndian:
            var value = Float64(data)
            let leData = Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
            var data = Data(capacity: MemoryLayout.size(ofValue: value))
            for byte in leData.reversed() {
                data.append(byte)
            }
            return data
        }
    }
}

