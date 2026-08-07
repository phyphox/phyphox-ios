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

//Numeric helpers shared by the BLE config and output conversions. They replicate Java's
//primitive cast semantics so the resulting bytes are identical to Android's implementation
//(ConversionsConfig/ConversionsOutput).
enum JavaByteConversion {
    //Double to integer like a Java (int) cast: NaN becomes 0, out-of-range values saturate,
    //everything else is truncated towards zero.
    static func toInt32(_ value: Double) -> Int32 {
        if value.isNaN {
            return 0
        }
        if value >= Double(Int32.max) {
            return Int32.max
        }
        if value <= Double(Int32.min) {
            return Int32.min
        }
        return Int32(value.rounded(.towardZero))
    }

    static func toInt64(_ value: Double) -> Int64 {
        if value.isNaN {
            return 0
        }
        if value >= Double(Int64.max) {
            return Int64.max
        }
        if value <= Double(Int64.min) {
            return Int64.min
        }
        return Int64(value.rounded(.towardZero))
    }

    //The lowest `count` bytes of the value, least significant first
    static func littleEndian(_ value: Int64, count: Int) -> Data {
        var result = Data(capacity: count)
        for i in 0..<count {
            result.append(UInt8(truncatingIfNeeded: value >> (8*i)))
        }
        return result
    }
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
            //A dangling character of an odd-length string is ignored
            while index < hexString.endIndex, hexString.index(after: index) < hexString.endIndex {
                let next = hexString.index(after: index)
                let pair = hexString[index...next]
                if let num = UInt8(pair, radix: 16) {
                    result.append(num)
                } else {
                    return Data()
                }
                index = hexString.index(after: next)
            }
            return result
        case .uInt8, .int8:
            //Parse as Int and truncate, so both signed (-128..127) and unsigned (128..255) notations work
            guard let value = Int(data) else { return Data() }
            return Data([UInt8(truncatingIfNeeded: value)])
        default:
            guard let value = Double(data) else { return Data() }
            let bytes: Data
            switch function {
            case .uInt16LittleEndian, .int16LittleEndian, .uInt16BigEndian, .int16BigEndian:
                bytes = JavaByteConversion.littleEndian(Int64(JavaByteConversion.toInt32(value)), count: 2)
            case .uInt24LittleEndian, .int24LittleEndian, .uInt24BigEndian, .int24BigEndian:
                bytes = JavaByteConversion.littleEndian(Int64(JavaByteConversion.toInt32(value)), count: 3)
            case .int32LittleEndian, .int32BigEndian:
                bytes = JavaByteConversion.littleEndian(Int64(JavaByteConversion.toInt32(value)), count: 4)
            case .uInt32LittleEndian, .uInt32BigEndian:
                bytes = JavaByteConversion.littleEndian(JavaByteConversion.toInt64(value), count: 4)
            case .float32LittleEndian, .float32BigEndian:
                bytes = JavaByteConversion.littleEndian(Int64(Float(value).bitPattern), count: 4)
            case .float64LittleEndian, .float64BigEndian:
                bytes = JavaByteConversion.littleEndian(Int64(bitPattern: value.bitPattern), count: 8)
            default:
                return Data()
            }
            switch function {
            case .uInt16BigEndian, .int16BigEndian, .uInt24BigEndian, .int24BigEndian, .uInt32BigEndian, .int32BigEndian, .float32BigEndian, .float64BigEndian:
                return Data(bytes.reversed())
            default:
                return bytes
            }
        }
    }
}
