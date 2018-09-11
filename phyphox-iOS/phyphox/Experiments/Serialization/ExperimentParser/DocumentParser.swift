//
//  DocumentParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 Jonas Gessner. All rights reserved.
//

import Foundation

/// Used as key for `KeyedAttributeContainer`. To be used by enumerations with `String` raw values, which by default provide the `rawValue` getter.
protocol AttributeKey {
    var rawValue: String { get }
}

/// This tructure provides readonly access to attribute values for a specific `AttributeKey` key type.
struct KeyedAttributeContainer<Key: AttributeKey> {
    private let attributes: [String: String]

    fileprivate init(attributes: [String: String]) {
        self.attributes = attributes
    }

    func optionalString(for key: Key) -> String? {
        let keyString = key.rawValue

        return attributes[keyString]
    }

    func string(for key: Key) throws -> String {
        let keyString = key.rawValue

        guard let stringValue = attributes[keyString] else {
            throw ElementHandlerError.missingAttribute(keyString)
        }

        return stringValue
    }

    func nonEmptyString(for key: Key) throws -> String {
        let keyString = key.rawValue

        guard let stringValue = attributes[keyString], !stringValue.isEmpty else {
            throw ElementHandlerError.missingAttribute(keyString)
        }

        return stringValue
    }

    func optionalValue<T: LosslessStringConvertible>(for key: Key) throws -> T? {
        let keyString = key.rawValue

        return try attributes[keyString].map({
            guard let value = T.init($0) else {
                throw ElementHandlerError.unexpectedAttributeValue(keyString)
            }
            return value
        })
    }

    func value<T: LosslessStringConvertible>(for key: Key) throws -> T {
        let keyString = key.rawValue

        guard let stringValue = attributes[keyString] else {
            throw ElementHandlerError.missingAttribute(keyString)
        }

        guard let value = T.init(stringValue) else {
            throw ElementHandlerError.unexpectedAttributeValue(keyString)
        }

        return value
    }
}

/// Contiains attributes. Provides `KeyedAttributeContainer` for specific `AttributeKey` key types, which allows reading values.
struct AttributeContainer {
    private let attributes: [String: String]

    fileprivate static var empty: AttributeContainer {
        return AttributeContainer(attributes: [:])
    }

    fileprivate init(attributes: [String: String]) {
        self.attributes = attributes
    }

    func attributes<Key: AttributeKey>(keyedBy key: Key.Type) -> KeyedAttributeContainer<Key> {
        return KeyedAttributeContainer(attributes: attributes)
    }
}

/// Every element handler needs to coform to this protocol. This protocol is class-bound because `DocumentHandler` required element handlers to have reference semantics.
protocol ElementHandler: AnyObject {
    /// Called when the start tag for the element was encountered.
    func startElement(attributes: AttributeContainer) throws
    func childHandler(for elementName: String) throws -> ElementHandler
    func endElement(text: String, attributes: AttributeContainer) throws

    func clear()
    func clearChildHandlers()
}

/// Extends `ElementHandler` with a `Result` associated type and `results` array to represent results created by element handlers.
protocol ResultElementHandler: ElementHandler {
    associatedtype Result

    var results: [Result] { get set }
}

/// Flexible XML parser that forwards SAX events to objects conforming to `ElementHandler`. A specific document handler needs to be provided, which realizes the specific logic. This class synchronously parses an input document and returns the result produced by the document handler. Depending on what result the document handler produces, this class acts as a deserializer.
final class DocumentParser<DocumentHandler: ResultElementHandler>: NSObject, XMLParserDelegate {
    private let documentHandler: DocumentHandler

    /// Arrays used as stacks containing element name, element handler, text and attributes from parent elements relative to the current location within the XML file. At the root level, these contain an empty string, empty attributes, empty tag name and the root element handler.
    private var handlerStack = [(elementName: String, handler: ElementHandler)]()
    private var textStack = [String]()
    private var attributesStack = [AttributeContainer]()

    private var parsingError: Error?

    init(documentHandler: DocumentHandler) {
        self.documentHandler = documentHandler
        super.init()
    }

    /// Helper property that returns a backtrace to the current position within the XML file. Used for error reporting.
    private var currentElementBacktrace: String {
        return handlerStack.suffix(from: 1).map({ $0.elementName }).joined(separator: " > ")
    }

    /// Synchronously parses an XML file provided by an `InputStream` using the root handler of the parser.
    func parse(stream: InputStream) throws -> DocumentHandler.Result {
        parsingError = nil

        let parser = XMLParser(stream: stream)
        parser.delegate = self
        parser.parse()

        if let parseError = parsingError ?? parser.parserError {
            throw ParserError.parsingError(backtrace: currentElementBacktrace, line: parser.lineNumber, encounteredError: parseError)
        }

        guard let result = documentHandler.results.first else {
            throw ParserError.noResult
        }

        return result
    }

    /// Helper method that trims leading and trailing whitespaces, used to sanitize text content.
    private func cleanText(_ textToClean: String) -> String {
        return textToClean.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - XMLParserDelegate Methods
    func parserDidStartDocument(_ parser: XMLParser) {
        handlerStack = [("", documentHandler)]
        textStack = [""]
        attributesStack = [.empty]

        do {
            documentHandler.clear()
            documentHandler.clearChildHandlers()
            try documentHandler.startElement(attributes: .empty)
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
            let elementAttributes = AttributeContainer(attributes: attributes)
            try childHandler.startElement(attributes: elementAttributes)

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
        guard let currentText = textStack.popLast() else {
            parser.abortParsing()
            return
        }
        
        textStack.append(currentText + string)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard let currentText = textStack.popLast(),
            let (currentTagName, elementHandler) = handlerStack.popLast(),
            let attributes = attributesStack.popLast(),
            elementName == currentTagName else {
                parser.abortParsing()
                return
        }

        do {
            try elementHandler.endElement(text: cleanText(currentText), attributes: attributes)
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
            try documentHandler.endElement(text: cleanText(currentText), attributes: attributes)
        }
        catch {
            parsingError = error
            parser.abortParsing()
        }
    }
}

fileprivate extension DocumentParser {
    /// Error describing possible errors encountered by DocumentParser
    enum ParserError: LocalizedError {
        case parsingError(backtrace: String, line: Int, encounteredError: Error)
        case noResult

        var errorDescription: String? {
            switch self {
            case .parsingError(backtrace: let backtrace, line: let line, encounteredError: let error):
                return "Parser encountered error on element \"\(backtrace)\" at line \(line): \(error.localizedDescription)"
            case .noResult:
                return "The document handler produced no result"
            }
        }
    }
}
