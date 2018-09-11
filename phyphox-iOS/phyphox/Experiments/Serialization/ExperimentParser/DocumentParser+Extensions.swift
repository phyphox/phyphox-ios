//
//  DocumentParser+Extensions.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 Jonas Gessner. All rights reserved.
//

import Foundation

/// Allows types conforming to the `RawRepresentable` protocol with a `RawValue` of type `String` to conform to `LosslessStringConvertible` without implementing any methods. Example: Enumerations with `String` raw values.
extension LosslessStringConvertible where Self: RawRepresentable, Self.RawValue == String {
    init?(_ description: String) {
        self.init(rawValue: description)
    }

    var description: String {
        return rawValue
    }
}

enum ElementHandlerError: Error {
    /// To be used when a child element that cannot be handled is encountered
    case unexpectedChildElement(String)

    /// To be used by when an element has attributes it cannot handle
    case unexpectedAttribute(String)

    case missingText

    /// Signals that a required attribute is missing
    case missingAttribute(String)

    /// Signals an unexpected, unreadable value for an attribute name
    case unexpectedAttributeValue(String)

    /// To be used by an element when a child element is missing.
    case missingChildElement(String)

    /// To be used when an element is missing. An empty string signalizes that element handler has no results but expects one, hene the element handler itself is missing a parsed element.
    case missingElement(String)

    /// To be called by an element handler that expects only one result but has produced several.
    case duplicateElement

    /// Unreadable (i.e. corrupted) data
    case unreadableData

    /// Custom error message
    case message(String)
}

extension ElementHandlerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .duplicateElement:
            return "Duplicate element"
        case .missingAttribute(let attribute):
            return "Attribute \"\(attribute)\" is missing"
        case .missingChildElement(let element):
            return "Child element \"\(element)\" is missing"
        case .missingElement(let element):
            return element.isEmpty ? "Element is missing" : "Element \"\(element)\" is missing"
        case .missingText:
            return "Text value is missing"
        case .unexpectedAttribute(let attribute):
            return "Unexpected attribute \"\(attribute)\""
        case .unexpectedChildElement(let element):
            return "Unexpected child element \"\(element)\""
        case .unreadableData:
            return "Unreadable data"
        case .unexpectedAttributeValue(let attribute):
            return "Unexpected value for \"\(attribute)\""
        case .message(let message):
            return message
        }
    }
}

protocol LookupElementHandler: ElementHandler {
    var childHandlers: [String: ElementHandler] { get set }
}

extension LookupElementHandler {
    func clearChildHandlers() {
        childHandlers.values.forEach { $0.clear() }
    }

    func childHandler(for elementName: String) throws -> ElementHandler {
        guard let handler = childHandlers[elementName] else {
            throw ElementHandlerError.unexpectedChildElement(elementName)
        }

        return handler
    }
}

extension ResultElementHandler {
    func clear() {
        results.removeAll()
    }

    func expectOptionalResult() throws -> Result? {
        guard results.count <= 1 else {
            throw ElementHandlerError.duplicateElement
        }

        return results.first
    }

    func expectSingleResult() throws -> Result {
        guard let result = try expectOptionalResult() else {
            throw ElementHandlerError.missingElement("")
        }

        return result
    }

    func expectAtLeastOneResult() throws -> [Result] {
        guard !results.isEmpty else {
            throw ElementHandlerError.missingElement("")
        }

        return results
    }
}

protocol ChildlessElementHandler: ElementHandler {}

extension ChildlessElementHandler {
    func childHandler(for elementName: String) throws -> ElementHandler {
        throw ElementHandlerError.unexpectedChildElement(elementName)
    }

    func clearChildHandlers() {}
}

protocol AttributelessElementHandler: ElementHandler {}

extension AttributelessElementHandler {
    func startElement(attributes: AttributeContainer) throws {}
}

extension String: AttributeKey {
    var rawValue: String {
        return self
    }
}
