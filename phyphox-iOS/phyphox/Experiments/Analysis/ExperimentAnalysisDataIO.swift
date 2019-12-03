//
//  ExperimentAnalysisDataIO.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

enum ExperimentAnalysisDataIO: Equatable {
    case buffer(buffer: DataBuffer, usedAs: String, clear: Bool)
    case value(value: Double, usedAs: String)

    func getSingleValue() -> Double? {
        switch self {
        case .buffer(buffer: let buffer, usedAs: _, clear: _):
            return buffer.last
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
        case .buffer(buffer: _, usedAs: let usedAs, clear: _):
            return usedAs
        case .value(value: _, usedAs: let usedAs):
            return usedAs
        }
    }

    var isBuffer: Bool {
        switch self {
        case .buffer(buffer: _, usedAs: _, clear: _):
            return true
        case .value(value: _, usedAs: _):
            return false
        }
    }
}
