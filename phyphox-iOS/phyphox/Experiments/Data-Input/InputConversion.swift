//
//  ConversionInput.swift
//  phyphox
//
//  Created by Sebastian Staacks on 21.05.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation

protocol InputConversion {
    func convert(data: Data) -> Double
}

class SimpleInputConversion: InputConversion {
    enum ConversionFunction: String, LosslessStringConvertible {
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
    
    let offset: Int
    let length: Int?
    let function: ConversionFunction
    
    init(function: ConversionFunction, offset: Int, length: Int?) {
        self.function = function
        self.offset = offset
        self.length = length
    }
    
    func convert(data: Data) -> Double {
        let length = self.length ?? data.count - offset
        if length < 1 || data.count < offset + length {
            return Double.nan
        }
        let subdata = data.subdata(in: Range(offset..<offset+length))
        switch function {
        case .uInt8:
            if subdata.count < 1 {
                return Double.nan
            }
            let result: UInt8 = subdata.withUnsafeBytes{$0.pointee}
            return Double(result)
        case .int8:
            if subdata.count < 1 {
                return Double.nan
            }
            let result: Int8 = subdata.withUnsafeBytes{$0.pointee}
            return Double(result)
        case .uInt16LittleEndian:
            if subdata.count < 2 {
                return Double.nan
            }
            let result: UInt16 = subdata.withUnsafeBytes{$0.pointee}
            return Double(result)
        case .int16LittleEndian:
            if subdata.count < 2 {
                return Double.nan
            }
            let result: Int16 = subdata.withUnsafeBytes{$0.pointee}
            return Double(result)
        case .uInt16BigEndian:
            if subdata.count < 2 {
                return Double.nan
            }
            let result: UInt16 = UInt16(bigEndian: subdata.withUnsafeBytes{$0.pointee})
            return Double(result)
        case .int16BigEndian:
            if subdata.count < 2 {
                return Double.nan
            }
            let result: Int16 = Int16(bigEndian: subdata.withUnsafeBytes{$0.pointee})
            return Double(result)
        case .uInt24LittleEndian:
            if subdata.count < 3 {
                return Double.nan
            }
            var extendedData = Data()
            if subdata[0] & 0x80 > 0 {
                extendedData.append(0xff)
            } else {
                extendedData.append(0x00)
            }
            extendedData.append(subdata)
            let result: UInt32 = subdata.withUnsafeBytes{$0.pointee}
            return Double(result)
        case .int24LittleEndian:
            if subdata.count < 3 {
                return Double.nan
            }
            let result: Int32 = subdata.withUnsafeBytes{$0.pointee}
            return Double(result)
        case .uInt24BigEndian:
            if subdata.count < 3 {
                return Double.nan
            }
            var extendedData = subdata
            extendedData.append(0x00)
            let result: UInt32 = UInt32(bigEndian: subdata.withUnsafeBytes{$0.pointee})
            return Double(result)
        case .int24BigEndian:
            if subdata.count < 3 {
                return Double.nan
            }
            var extendedData = Data()
            extendedData.append(subdata)
            if subdata[2] & 0x80 > 0 {
                extendedData.append(0xff)
            } else {
                extendedData.append(0x00)
            }
            let result: Int32 = Int32(bigEndian: subdata.withUnsafeBytes{$0.pointee})
            return Double(result)
        case .uInt32LittleEndian:
            if subdata.count < 4 {
                return Double.nan
            }
            let result: UInt32 = subdata.withUnsafeBytes{$0.pointee}
            return Double(result)
        case .int32LittleEndian:
            if subdata.count < 4 {
                return Double.nan
            }
            let result: Int32 = subdata.withUnsafeBytes{$0.pointee}
            return Double(result)
        case .uInt32BigEndian:
            if subdata.count < 4 {
                return Double.nan
            }
            let result: UInt32 = UInt32(bigEndian: subdata.withUnsafeBytes{$0.pointee})
            return Double(result)
        case .int32BigEndian:
            if subdata.count < 4 {
                return Double.nan
            }
            let result: Int32 = Int32(bigEndian: subdata.withUnsafeBytes{$0.pointee})
            return Double(result)
        case .float32LittleEndian:
            if subdata.count < 4 {
                return Double.nan
            }
            let result: Float32 = subdata.withUnsafeBytes{$0.pointee}
            return Double(result)
        case .float32BigEndian:
            if subdata.count < 4 {
                return Double.nan
            }
            let result: Float32 = CFConvertFloat32SwappedToHost(subdata.withUnsafeBytes{$0.pointee})
            return Double(result)
        case .float64LittleEndian:
            if subdata.count < 8 {
                return Double.nan
            }
            let result: Float64 = subdata.withUnsafeBytes{$0.pointee}
            return Double(result)
        case .float64BigEndian:
            if subdata.count < 8 {
                return Double.nan
            }
            let result: Float64 = CFConvertFloat64SwappedToHost(subdata.withUnsafeBytes{$0.pointee})
            return Double(result)
        }
    }
}

class StringInputConversion: InputConversion {
    let decimalPoint: String?
    let offset: Int
    let length: Int?
    
    init(decimalPoint: String?, offset: Int, length: Int?) {
        self.decimalPoint = decimalPoint
        self.offset = offset
        self.length = length
    }
    
    func convert(data: Data) -> Double {
        let length = self.length ?? data.count - offset
        if length < 1 || data.count < offset + length {
            return Double.nan
        }
        let subdata = data.subdata(in: Range(offset..<offset+length))
        guard var str: String = String(data: subdata, encoding: .utf8) else {
            return Double.nan
        }

        if let decimalPoint = decimalPoint {
           str = str.replacingOccurrences(of: decimalPoint, with: ".")
        }
        return Double(str) ?? Double.nan
    }
}

class FormattedStringInputConversion: InputConversion {
    let separator: String?
    let label: String?
    let index: Int
    
    init(separator: String?, label: String?, index: Int) {
        self.separator = separator
        self.label = label
        self.index = index
    }
    
    func convert(data: Data) -> Double {
        guard let str: String = String(data: data, encoding: .utf8) else {
            return Double.nan
        }

        var parts: [Substring]
        if let separator = separator?.first {
            parts = str.split(separator: separator)
        } else {
            parts = [Substring(str)]
        }
                
        if parts.count <= index {
            return Double.nan
        }
        
        if let label = label, label != "" {
            //Use label to find relevant part
            for part in parts {
                if part.starts(with: label) {
                    return Double(part[part.index(part.startIndex, offsetBy: label.count)...]) ?? Double.nan
                }
            }
            return Double.nan
        } else {
            //Use index to find relevant part (CSV style)
            return Double(parts[index].trimmingCharacters(in: .whitespacesAndNewlines)) ?? Double.nan
        }
    }
}
