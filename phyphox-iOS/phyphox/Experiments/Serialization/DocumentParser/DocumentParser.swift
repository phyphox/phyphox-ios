//
//  DocumentParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 Jonas Gessner. All rights reserved.
//

import Foundation
import zlib

// MARK: - Attributes
/// KeyedAttributeContainer and AttributeContainer are defined in the same file as DocumentParser to allow their initializers to be fileprivate. This makes it possible for DocumentParser to initialize AttributeContainer but makes it impossible to initialize AttributeContainer from outside this file.

/// Used as key for `KeyedAttributeContainer`. To be used by enumerations with `String` raw values, which by default provide the `rawValue` getter.
protocol AttributeKey {
    var rawValue: String { get }
}

/// This tructure provides readonly access to attribute values for a specific `AttributeKey` key type.
struct KeyedAttributeContainer<Key: AttributeKey> {
    /// The raw, underlying attribute dictionary
    private let attributes: [String: String]

    fileprivate init(attributes: [String: String]) {
        self.attributes = attributes
    }

    /// Returns the original, optional string value for the provided key.
    func optionalString(for key: Key) -> String? {
        let keyString = key.rawValue

        return attributes[keyString]
    }

    /// Returns a non-optional string for the provided key. Throws an error when no value exists for the provided key.
    func string(for key: Key) throws -> String {
        let keyString = key.rawValue

        guard let stringValue = attributes[keyString] else {
            throw ElementHandlerError.missingAttribute(keyString)
        }

        return stringValue
    }

    /// Returns a non-optional, non-empty string for the provided key. Throws an error when no value exists for the provided key or if the value is empty.
    func nonEmptyString(for key: Key) throws -> String {
        let stringValue = try string(for: key)

        guard !stringValue.isEmpty else {
            throw ElementHandlerError.missingText
        }

        return stringValue
    }

    /// Returns an optional value of type `T` for the provided key, where `T` is `LosslessStringConvertible`. Throws an error decoding to `T` fails.
    func optionalValue<T: LosslessStringConvertible>(for key: Key) throws -> T? {
        let keyString = key.rawValue

        return try attributes[keyString].map({
            guard let value = T.init($0) else {
                throw ElementHandlerError.unexpectedAttributeValue(keyString)
            }

            return value
        })
    }

    /// Returns a non-optional value of type `T` for the provided key, where `T` is `LosslessStringConvertible`. Throws an error when no value exists for the provided key or if decoding to `T` fails.
    func value<T: LosslessStringConvertible>(for key: Key) throws -> T {
         let keyString = key.rawValue
        guard let stringValue = attributes[keyString] else {
            throw ElementHandlerError.missingAttribute(key.rawValue)
        }
        guard let value = T.init(stringValue) else {
            throw ElementHandlerError.unexpectedAttributeValue(keyString)
        }
        return value
    }
}

/// Contiains attributes. Provides `KeyedAttributeContainer` for specific `AttributeKey` key types, which allows reading values.
struct AttributeContainer: Equatable {
    /// The raw, underlying attribute dictionary
    private let attributes: [String: String]

    /// Returns an empty attribute container
    static var empty: AttributeContainer {
        return AttributeContainer(attributes: [:])
    }

    fileprivate init(attributes: [String: String]) {
        self.attributes = attributes
    }

    /// Creates and returns a `KeyedAttributeContainer` for the provided key type, providing access to the attributes from the attribute container.
    func attributes<Key: AttributeKey>(keyedBy key: Key.Type) -> KeyedAttributeContainer<Key> {
        return KeyedAttributeContainer(attributes: attributes)
    }
}

// MARK: - Element Handlers

/// Every element handler needs to coform to this protocol. This protocol is class-bound because `DocumentHandler` required element handlers to have reference semantics.
protocol ElementHandler: AnyObject {
    /// Called when the start tag for the element was encountered. Provides the element's attributes.
    func startElement(attributes: AttributeContainer) throws
    /// Called when a child element is encountered. This method needs to return the appropriate element handler for the child element or throw an error.
    func childHandler(for elementName: String) throws -> ElementHandler
    /// Called when the end tag for the element was encountered. Provides the element's attributes and the text content of the element.
    func endElement(text: String, attributes: AttributeContainer) throws

    /// This method clears any results produced by the element handler.
    func clear()
    /// This method calls `clear` on all child element handlers.
    func clearChildHandlers()
}

/// Extends `ElementHandler` with a `Result` associated type and `results` array to represent results created by element handlers.
protocol ResultElementHandler: ElementHandler {
    associatedtype Result

    /// The results produced by an element handler. An element handler creates one instance of `Result` per element and appends it to this array.
    var results: [Result] { get set }
}

// MARK: - DocumentParser

/// Flexible XML parser that forwards SAX events to objects conforming to `ElementHandler`. A specific document handler needs to be provided, which realizes specific parsing or deserialization logic. This class synchronously parses an input document and returns the result produced by the document handler. See documentation for `init(documentHandler:)` for details on the document handler.
final class DocumentParser<DocumentHandler: ResultElementHandler>: NSObject, XMLParserDelegate {
    private let documentHandler: DocumentHandler

    /// Arrays used as stacks containing element name, element handler, text and attributes from parent elements relative to the current location within the XML file. At the root level, these contain an empty string, empty attributes, empty tag name and the root element handler.
    private var handlerStack = [(elementName: String, handler: ElementHandler)]()
    private var textStack = [String]()
    private var attributesStack = [AttributeContainer]()

    /// Used internally to store errors thrown by element handlers
    private var parsingError: Error?

    /// Initializer for a reusable document parser. The document handler is a result element handler responsible for the entire document. Its `startElement` method is called when parsing the document begins and is provided with empty attributes. The `childHandler` method is called when the root element is encountered. The document handler needs to return the element handler for the root element, if the root element name is known, or throw an error. The `endElement` method is called when parsing the document has finished. This methid is called with empty attributes and empty text content. The implementaiton of `endElement` of the document handler needs to produce its resulting object and append it to its `results` array. The document parser subsequently returns the produced result from the `parse(stream)` method.
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

        // Prepare stacks, clear document handler. Could also be done in parserDidStartDocument instead, but is safer to do here in case parserDidStartDocument never gets called (i.e. in an error situation). These operations are shown to be performed in parserDidStartDocument in the thesis to simplify the explanation.
        handlerStack = [("", documentHandler)]
        textStack = [""]
        attributesStack = [.empty]

        documentHandler.clear()
        documentHandler.clearChildHandlers()

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

    // MARK: XMLParserDelegate Methods
    // These methods realize the forwarding of SAX events to the appropriate element handlers by using handlerStack, textStack and attributesStack.

    func parserDidStartDocument(_ parser: XMLParser) {
        do {
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
    /// Private, namespaced error describing possible errors encountered by `DocumentParser`.
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
