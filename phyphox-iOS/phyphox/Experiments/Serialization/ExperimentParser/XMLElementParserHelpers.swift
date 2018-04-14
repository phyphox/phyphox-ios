//
//  XMLElementParserHelpers.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

enum XMLElementParserError: Error {
    /// To be used when a child element that cannot be handled is encountered
    case unexpectedChildElement(String)

    /// To be used by when an element has attributes it cannot handle
    case unexpectedAttribute(String)

    case missingText

    /// Signals that a required attribute is missing
    case missingAttribute(String)

    /// Signals an unexpected, unreadable value for an attribute name
    case unexpectedValue(String)

    /// To be used by an element when a child element is missing.
    case missingChildElement(String)

    /// To be used by any element when another element is missing.
    case missingElement(String)

    /// To be used by an element handler when it has no results but expects one.
    case missingSelf

    /// To be called by an element handler that expects only one result but has produced several.
    case duplicateElement

    /// Unreadable (binary) data
    case unreadableData
}

extension XMLElementParserError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .duplicateElement:
            return "Duplicate element"
        case .missingAttribute(let attribute):
            return "Attribute \"\(attribute)\" is missing"
        case .missingChildElement(let element):
            return "Child element \"\(element)\" is missing"
        case .missingElement(let element):
            return "Element \"\(element)\" is missing"
        case .missingSelf:
            return "Element is missing"
        case .missingText:
            return "Text value is missing"
        case .unexpectedAttribute(let attribute):
            return "Unexpected attribute \"\(attribute)\""
        case .unexpectedChildElement(let element):
            return "Unexpected child element \"\(element)\""
        case .unreadableData:
            return "Unreadable data"
        case .unexpectedValue(let attribute):
            return "Unexpected value for \"\(attribute)\""
        }
    }
}

protocol LookupElementHandler: ElementHandler {
    var handlers: [String: ElementHandler] { get set }
}

extension LookupElementHandler {
    mutating func clearChildHandlers() {
        var mutatedHandlers = handlers

        for (key, var handler) in mutatedHandlers {
            handler.clear()
            mutatedHandlers[key] = handler
        }

        handlers = mutatedHandlers
    }

    func childHandler(for tagName: String) throws -> ElementHandler {
        guard let handler = handlers[tagName] else {
            throw XMLElementParserError.unexpectedChildElement(tagName)
        }

        return handler
    }
}

protocol ResultElementHandler: ElementHandler {
    associatedtype Result

    var results: [Result] { get set }

    func expectOptionalResult() throws -> Result?
    func expectSingleResult() throws -> Result
    func expectAtLeastOneResult() throws -> [Result]
}

extension ResultElementHandler {
    mutating func clear() {
        results.removeAll()
        clearChildHandlers()
    }

    func expectOptionalResult() throws -> Result? {
        guard results.count <= 1 else {
            throw XMLElementParserError.duplicateElement
        }

        return results.first
    }

    func expectSingleResult() throws -> Result {
        guard let result = results.first else {
            throw XMLElementParserError.missingSelf
        }

        guard results.count == 1 else {
            throw XMLElementParserError.duplicateElement
        }

        return result
    }

    func expectAtLeastOneResult() throws -> [Result] {
        guard !results.isEmpty else {
            throw XMLElementParserError.missingSelf
        }

        return results
    }
}

protocol AttributelessHandler: ElementHandler {}

extension AttributelessHandler {
    func beginElement(attributes: [String: String]) throws {
        guard attributes.isEmpty else {
            throw XMLElementParserError.unexpectedAttribute(attributes.keys.first ?? "")
        }
    }
}

protocol ChildlessHandler: ElementHandler {}

extension ChildlessHandler {
    func childHandler(for tagName: String) throws -> ElementHandler {
        throw XMLElementParserError.unexpectedChildElement(tagName)
    }

    func clearChildHandlers() {
    }
}

func attribute<T: LosslessStringConvertible>(_ key: String, from attributes: [String: String]) -> T? {
    return attributes[key].map({ T.init($0) }) ?? nil
}

func attribute<T: LosslessStringConvertible>(_ key: String, from attributes: [String: String], defaultValue: T) -> T {
    return attributes[key].map({ T.init($0) ?? defaultValue }) ?? defaultValue
}
