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
            out.append(UInt8(truncatingIfNeeded: JavaByteConversion.toInt32(value)))
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
            //Match Java's Double.toString for the non-finite values
            if value.isNaN {
                return "NaN".data(using: .utf8)
            }
            if value.isInfinite {
                return (value > 0 ? "Infinity" : "-Infinity").data(using: .utf8)
            }
            return "\(value)".data(using: .utf8)
        case .uInt8, .int8:
            return Data([UInt8(truncatingIfNeeded: JavaByteConversion.toInt32(value))])
        default:
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
                return nil
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
