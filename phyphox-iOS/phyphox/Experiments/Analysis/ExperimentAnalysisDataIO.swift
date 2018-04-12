//
//  ExperimentAnalysisDataIO.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

enum ExperimentAnalysisDataIO {
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

// TODO: Remove legacy code
extension ExperimentAnalysisDataIO {
    init(buffer: DataBuffer) {
        self = .buffer(buffer: buffer, usedAs: "", clear: false)
    }

    init(dictionary: NSDictionary, buffers: [String: DataBuffer]) throws {
        var typeIsValue = false
        var typeIsEmpty = false

        let asString: String
        let clear: Bool

        if let attributes = dictionary[XMLDictionaryAttributesKey] as? [String: AnyObject] {
            asString = stringFromXML(attributes, key: "as", defaultValue: "")

            let type = stringFromXML(attributes, key: "type", defaultValue: "")

            if type == "value" {
                typeIsValue = true
            } else if type == "empty" {
                typeIsEmpty = true
            }

            clear = boolFromXML(attributes, key: "clear", defaultValue: true)
        }
        else {
            throw SerializationError.invalidExperimentFile(message: "Error! Input or output tag missing reference.")
        }

        let text = dictionary[XMLDictionaryTextKey] as? String

        if typeIsValue {
            if let text = text, let value = Double(text) {
                self = .value(value: value, usedAs: asString)
            }
            else {
                throw SerializationError.invalidExperimentFile(message: "Error! Input or output tag missing reference.")
            }
        }
        else if !typeIsEmpty {
            if let text = text, let buffer = buffers[text] {
                self = .buffer(buffer: buffer, usedAs: asString, clear: clear)
            }
            else {
                throw SerializationError.invalidExperimentFile(message: "Error! Input or output tag missing reference.")
            }
        }
        else {
            throw SerializationError.invalidExperimentFile(message: "Error! Input or output tag missing reference.")
        }
    }
}
