//
//  DocumentParser+Extensions.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 Jonas Gessner. All rights reserved.
//

import Foundation

// This file contains useful extensions to `DocumentParser`, specifically to element handlers.

/// Common error situations encountered by element handlers.
enum ElementHandlerError: Error {
    /// To be used when a child element that cannot be handled is encountered.
    case unexpectedChildElement(String)

    /// To be used by when an element has attributes it cannot handle.
    case unexpectedAttribute(String)

    /// Missing (empty) text content.
    case missingText

    /// Signals that a required attribute is missing.
    case missingAttribute(String)

    /// Signals an unexpected, unreadable value for an attribute name.
    case unexpectedAttributeValue(String)

    /// To be used by an element when a child element is missing.
    case missingChildElement(String)

    /// To be used when an element is missing. An empty string signalizes that element handler has no results but expects one, hene the element handler itself is missing a parsed element.
    case missingElement(String)

    /// To be called by an element handler that expects only one result but has produced several.
    case duplicateElement

    /// Unreadable (i.e. corrupted) data.
    case unreadableData

    /// Custom error message.
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

/// Specialized element handler protocol, providing the implementation of `childHandler(for:)` and `clearChildHandlers`. The `childHandlers` getter needs to return a mapping from element name to element handler.
protocol LookupElementHandler: ElementHandler {
    var childHandlers: [String: ElementHandler] { get set }
}

extension LookupElementHandler {
    func clearChildHandlers() {
        childHandlers.values.forEach { $0.clear() }
    }

    func childHandler(for elementName: String) throws -> ElementHandler {
        //Element names are matched case-insensitively, like the enumerated values
        //(enum-case-insensitive in phyphox-docs; the Android block parsers lowercase their tags).
        //All registered handler names are lowercase.
        guard let handler = childHandlers[elementName.lowercased()] else {
            throw ElementHandlerError.unexpectedChildElement(elementName)
        }

        return handler
    }
}

/// Extensions for `ResultElementHandler`, providing easy access to results along with verification of their multiplicity.
extension ResultElementHandler {
    func clear() {
        results.removeAll()
    }

    /// Returns an optional result, or throws an error if more than one result exists.
    func expectOptionalResult() throws -> Result? {
        guard results.count <= 1 else {
            throw ElementHandlerError.duplicateElement
        }

        return results.first
    }

    /// Returns the single result object, throws error otherwise.
    func expectSingleResult() throws -> Result {
        guard let result = try expectOptionalResult() else {
            throw ElementHandlerError.missingElement("")
        }

        return result
    }

    /// Returns non-empty results array, throws error otherwise.
    func expectAtLeastOneResult() throws -> [Result] {
        guard !results.isEmpty else {
            throw ElementHandlerError.missingElement("")
        }

        return results
    }
}

/// Specialized element handler protocol for element handlers expecting no child elements. Provides the implementation for `childHandler(for:)`, which always throws an error, as no child elements are expected. It also provides `clearChildHandlers` as an empty method, as no child handlers exists, hence clearing all child handlers does nothing.
protocol ChildlessElementHandler: ElementHandler {}

extension ChildlessElementHandler {
    func childHandler(for elementName: String) throws -> ElementHandler {
        throw ElementHandlerError.unexpectedChildElement(elementName)
    }

    func clearChildHandlers() {}
}

/// Specialized element handler protocol for element handlers expecting no attributes. Provides the implementation for `startElement`, does nothing. This method is only provided with the element's attributes and therefore is only used to read attributes. When no attributes are expected, no attributes are read and hence the method is left empty.
protocol AttributelessElementHandler: ElementHandler {}

extension AttributelessElementHandler {
    func startElement(attributes: AttributeContainer) throws {}
}

/// An enumerated value decoded from an experiment file attribute. Decoding folds case: an exact
/// match of the raw value is tried first, then the cases are scanned with case folded on both
/// sides, so camelCase raw values like prioritizeFramerate are found too (enum-case-insensitive
/// rule in phyphox-docs, matching the Android parser). Folding happens before rejection - a value
/// that matches no case at all fails the init, which the attribute readers report as an error.
///
/// This is deliberately its own protocol rather than a `LosslessStringConvertible` conformance:
/// the folding init accepts several spellings of the same value, which would stretch that
/// protocol's contract. The description (used wherever such an enum is printed or written out) is
/// the canonical raw value.
///
/// A String enum conforms by declaring this protocol together with `CaseIterable`. No allowed set
/// may contain two values differing only in case - the folding scan would silently pick the first.
protocol CaseInsensitiveAttributeDecodable: CustomStringConvertible {
    init?(attributeValue: String)
}

extension CaseInsensitiveAttributeDecodable where Self: RawRepresentable & CaseIterable, Self.RawValue == String {
    init?(attributeValue: String) {
        if let value = Self.init(rawValue: attributeValue) {
            self = value
            return
        }
        let folded = attributeValue.lowercased()
        guard let match = Self.allCases.first(where: { $0.rawValue.lowercased() == folded }) else {
            return nil
        }
        self = match
    }

    var description: String {
        return rawValue
    }
}
