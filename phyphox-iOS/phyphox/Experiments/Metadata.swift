//
//  NetworkMetadata.swift
//  phyphox
//
//  Created by Sebastian Staacks on 27.11.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation
import CommonCrypto

enum SensorMetadata: String, LosslessStringConvertible, CaseIterable {
    case name
    case vendor
    case range
    case resolution
    case minDelay
    case maxDelay
    case power
    case version
}

enum Metadata: CaseIterable {
    
    case uniqueId
    case version
    case build
    case fileFormat
    case deviceModel
    case deviceBrand
    case deviceBoard
    case deviceManufacturer
    case deviceBaseOS
    case deviceCodename
    case deviceRelease
    case sensor(SensorType, SensorMetadata)
    
    static var allCases: [Metadata] {
        var list = allNonSensorCases
        for sensorType in SensorType.allCases {
            for sensorMeta in SensorMetadata.allCases {
                list.append(.sensor(sensorType, sensorMeta))
            }
        }
        return list
    }
    
    static var allNonSensorCases: [Metadata] {
        return [.uniqueId, .version, .build, .fileFormat, .deviceModel, deviceBrand, deviceBoard, deviceManufacturer, deviceBaseOS, deviceCodename, deviceRelease]
    }
    
    var identifier: String {
        switch self {
        case .uniqueId:
            return "uniqueId"
        case .version:
            return "version"
        case .build:
            return "build"
        case .fileFormat:
            return "fileFormat"
        case .deviceModel:
            return "deviceModel"
        case .deviceBrand:
            return "deviceBrand"
        case .deviceBoard:
            return "deviceBoard"
        case .deviceManufacturer:
            return "deviceManufacturer"
        case .deviceBaseOS:
            return "deviceBaseOS"
        case .deviceCodename:
            return "deviceCodename"
        case .deviceRelease:
            return "deviceRelease"
        case .sensor(let sensorType, let sensorMeta):
            return sensorType.rawValue + sensorMeta.rawValue.capitalized
        }
    }
    
    func get(hash: String) -> String? {
        switch self {
        case .uniqueId:
            guard let deviceID = UIDevice.current.identifierForVendor?.uuidString else {
                return nil
            }
            guard let data = String(deviceID+hash).data(using: .utf8) else {
                return nil
            }
            let hash = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
                var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
                CC_MD5(bytes.baseAddress, CC_LONG(data.count), &hash)
                return hash
            }
            return hash.map { String(format: "%02x", $0)}.joined()
        case .version:
            return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        case .build:
            return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        case .fileFormat:
            return "\(latestSupportedFileVersion.major).\(latestSupportedFileVersion.minor)"
        case .deviceModel:
            var systemInfo = utsname()
            uname(&systemInfo)
            let modelCode = withUnsafePointer(to: &systemInfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                    ptr in String.init(validatingUTF8: ptr)
                }
            }
            return String.init(validatingUTF8: modelCode!)!
        case .deviceBrand:
            return "Apple"
        case .deviceRelease:
            return UIDevice.current.systemVersion
        default:
            return nil
        }
    }
}

