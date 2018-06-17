//
//  XMLElementParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

protocol XMLAttributeKey {
    var rawValue: String { get }
}

struct XMLElementAttributes<Key: XMLAttributeKey> {
    private let attributes: [String: String]

    /*fileprivate*/ init(attributes: [String: String]) {
        self.attributes = attributes
    }

    func constrain(to keys: [Key]) throws {
        let allowedKeys = Set(keys.map { $0.rawValue })
        let availableKeys = Set(attributes.keys)

        let illegalKeys = availableKeys.subtracting(allowedKeys)

        guard let illegalKey = illegalKeys.first else { return }

        throw XMLElementParserError.unexpectedAttribute(illegalKey)
    }

    func optionalString(for key: Key) -> String? {
        let keyString = key.rawValue

        return attributes[keyString]
    }

    func string(for key: Key) throws -> String {
        let keyString = key.rawValue

        guard let stringValue = attributes[keyString] else {
            throw XMLElementParserError.missingAttribute(keyString)
        }

        return stringValue
    }

    func nonEmptyString(for key: Key) throws -> String {
        let keyString = key.rawValue

        guard let stringValue = attributes[keyString], !stringValue.isEmpty else {
            throw XMLElementParserError.missingAttribute(keyString)
        }

        return stringValue
    }

    func optionalAttribute<T: LosslessStringConvertible>(for key: Key) throws -> T? {
        let keyString = key.rawValue

        return try attributes[keyString].map({
            guard let value = T.init($0) else {
                throw XMLElementParserError.unexpectedAttributeValue(keyString)
            }
            return value
        })
    }

    func attribute<T: LosslessStringConvertible>(for key: Key) throws -> T {
        let keyString = key.rawValue

        guard let stringValue = attributes[keyString] else {
            throw XMLElementParserError.missingAttribute(keyString)
        }

        guard let value = T.init(stringValue) else {
            throw XMLElementParserError.unexpectedAttributeValue(keyString)
        }

        return value
    }

    func optionalAttribute<T: RawRepresentable>(for key: Key) throws -> T? where T.RawValue == String {
        let keyString = key.rawValue

        return try attributes[keyString].map({
            guard let value = T.init(rawValue: $0) else {
                throw XMLElementParserError.unexpectedAttributeValue(keyString)
            }
            return value
        })
    }

    func attribute<T: RawRepresentable>(for key: Key) throws -> T where T.RawValue == String {
        let keyString = key.rawValue

        guard let stringValue = attributes[keyString] else {
            throw XMLElementParserError.missingAttribute(keyString)
        }

        guard let value = T.init(rawValue: stringValue) else {
            throw XMLElementParserError.unexpectedAttributeValue(keyString)
        }

        return value
    }
}

/// Contains immutable attributes. Makes attributes accessible through a specific key
struct XMLElementAttributeContainer {
    private let attributes: [String: String]

    fileprivate static var empty: XMLElementAttributeContainer {
        return XMLElementAttributeContainer(attributes: [:])
    }

    fileprivate init(attributes: [String: String]) {
        self.attributes = attributes
    }

    func attributes<Key: XMLAttributeKey>(keyedBy key: Key.Type) -> XMLElementAttributes<Key> {
        return XMLElementAttributes(attributes: attributes)
    }
}

protocol ElementHandler: class {
    func beginElement(attributeContainer: XMLElementAttributeContainer) throws
    func childHandler(for tagName: String) throws -> ElementHandler
    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws

    func clear()
    func clearChildHandlers()
}

protocol ResultElementHandler: ElementHandler {
    associatedtype Result

    var results: [Result] { get set }
}

/// Elemeht handler based XML parser
final class XMLElementParser<RootHandler: ResultElementHandler>: NSObject, XMLParserDelegate {
    private let rootHandler: RootHandler

    /// Arrays used as stacks containing element name, element handler, text and attributes from parent elements relative to the current location within the XML file. At the root level, these contain an empty string, empty attributes, empty tag name and the root element handler.
    private var handlerStack = [(tagName: String, elementHandler: ElementHandler)]()
    private var textStack = [String]()
    private var attributesStack = [XMLElementAttributeContainer]()

    private var parsingError: Error?

    init(rootHandler: RootHandler) {
        self.rootHandler = rootHandler
        super.init()
    }

    /// Helper property that returns a backtrace to the current position within the XML file. Used for error reporting.
    private var currentElementBacktrace: String {
        return handlerStack.map({ $0.tagName }).joined(separator: " > ")
    }

    /// Synchronously parses an XML file provided by an `InputStream` using the root handler of the parser.
    func parse(stream: InputStream) throws -> RootHandler.Result {
        handlerStack = [("", rootHandler)]
        textStack = [""]
        attributesStack = [.empty]
        parsingError = nil

        let parser = XMLParser(stream: stream)
        parser.delegate = self
        parser.parse()

        if let parseError = parsingError ?? parser.parserError {
            throw ParsingError.parsingError(backtrace: currentElementBacktrace, encounteredError: parseError)
        }

        guard let result = rootHandler.results.first else {
            throw ParsingError.missingRootElement
        }

        return result
    }

    /// Helper method that trims leading and trailing whitespaces, used to sanitize text found within XML tags.
    private func cleanText(_ textToClean: String) -> String {
        return textToClean.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - XMLParserDelegate

    func parserDidStartDocument(_ parser: XMLParser) {
        guard let attributes = attributesStack.last else {
            parser.abortParsing()
            return
        }

        do {
            rootHandler.clear()
            try rootHandler.beginElement(attributeContainer: attributes)
        }
        catch {
            parsingError = error
            parser.abortParsing()
        }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
        guard let (_, currentHandler) = handlerStack.last else {
            parser.abortParsing()
            return
        }

        do {
            let childHandler = try currentHandler.childHandler(for: elementName)

            childHandler.clearChildHandlers()
            let elementAttributes = XMLElementAttributeContainer(attributes: attributes)
            try childHandler.beginElement(attributeContainer: elementAttributes)

            attributesStack.append(elementAttributes)
            handlerStack.append((elementName, childHandler))
            textStack.append("")
        }
        catch {
            parsingError = error
            parser.abortParsing()
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard var currentText = textStack.popLast() else {
            parser.abortParsing()
            return
        }

        currentText += string

        textStack.append(currentText)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard let currentText = textStack.popLast(),
            let (currentTagName, elementHandler) = handlerStack.popLast(),
            let attributes = attributesStack.popLast(),
            elementName == currentTagName
            else {
                parser.abortParsing()
                return
        }

        do {
            try elementHandler.endElement(with: cleanText(currentText), attributeContainer: attributes)
        }
        catch {
            parsingError = error
            parser.abortParsing()
        }
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        guard let currentText = textStack.popLast(),
            let attributes = attributesStack.popLast()
            else {
                parser.abortParsing()
                return
        }
        
        do {
            try rootHandler.endElement(with: cleanText(currentText), attributeContainer: attributes)
        }
        catch {
            parsingError = error
            parser.abortParsing()
        }
    }
}

fileprivate extension XMLElementParser {
    enum ParsingError: LocalizedError {
        case parsingError(backtrace: String, encounteredError: Error)
        case missingRootElement

        var errorDescription: String? {
            switch self {
            case .parsingError(backtrace: let backtrace, encounteredError: let error):
                return "Parser encountered error on element \"\(backtrace)\": \(error.localizedDescription)"
            case .missingRootElement:
                return "The root element handler returned no result"
            }
        }
    }
}
