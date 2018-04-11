//
//  XMLFileParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

enum ParseError: Error {
    case unexpectedElement
    case unexpectedAttribute
    case missingText
    case missingAttribute(String)
    case unexpectedValue(String)
    case unreadableData
    case missingElement
    case duplicateElement
    case unbalancedTags
    case unexpectedText
}

// TODO: localizable error

protocol ElementHandler {
    mutating func beginElement(attributes: [String: String]) throws
    func childHandler(for tagName: String) throws -> ElementHandler
    mutating func endElement(with text: String) throws
}

protocol RootElementHandler: ElementHandler {
    associatedtype Result

    var result: Result? { get }
}

protocol ChildElementHandler: ElementHandler {
    associatedtype Parent: ElementHandler

    var parent: Parent? { get }
}

protocol ResultElementHandler: ElementHandler {
    associatedtype Result

    var results: [Result] { get }

    func expectOptionalResult() throws -> Result?
    func expectSingleResult() throws -> Result
    func expectAtLeastOneResult() throws -> [Result]
}

extension ResultElementHandler {
    func expectOptionalResult() throws -> Result? {
        guard results.count <= 1 else {
            throw ParseError.duplicateElement
        }

        return results.first
    }

    func expectSingleResult() throws -> Result {
        guard let result = results.first else {
            throw ParseError.missingElement
        }

        guard results.count == 1 else {
            throw ParseError.duplicateElement
        }

        return result
    }

    func expectAtLeastOneResult() throws -> [Result] {
        guard !results.isEmpty else {
            throw ParseError.missingElement
        }

        return results
    }
}

protocol LookupResultElementHandler: ResultElementHandler {
    var handlers: [String: ElementHandler] { get }
}

extension LookupResultElementHandler {
    func childHandler(for tagName: String) throws -> ElementHandler {
        guard let handler = handlers[tagName] else {
            throw ParseError.unexpectedElement
        }

        return handler
    }
}

protocol AttributeLessResultHandler: ResultElementHandler {}

extension AttributeLessResultHandler {
    func beginElement(attributes: [String: String]) throws {
        guard attributes.isEmpty else {
            throw ParseError.unexpectedAttribute
        }
    }
}

protocol ChildLessResultHandler: ResultElementHandler {}

extension ChildLessResultHandler {
    func childHandler(for tagName: String) throws -> ElementHandler {
        throw ParseError.unexpectedElement
    }
}

func attribute<T: LosslessStringConvertible>(_ key: String, from attributes: [String: String]) -> T? {
    return attributes[key].map({ T.init($0) }) ?? nil
}

func attribute<T: LosslessStringConvertible>(_ key: String, from attributes: [String: String], defaultValue: T) -> T {
    return attributes[key].map({ T.init($0) ?? defaultValue }) ?? defaultValue
}

final class XMLFileParser<Result, RootHandler: RootElementHandler>: NSObject, XMLParserDelegate where RootHandler.Result == Result {
    private let parser = XMLParser()

    private var rootHandler: RootHandler

    private var handlerStack: [(String, ElementHandler)]
    private var textStack = [""]

    private var parsingError: Error?

    init(rootHandler: RootHandler) {
        self.rootHandler = rootHandler
        handlerStack = [("", rootHandler)]
        super.init()
        parser.delegate = self
    }

    func parse(data: Data) throws -> Result {
        parsingError = nil

        parser.parse()

        if let parseError = parser.parserError {
            throw parseError
        }

        if let parseError = parsingError {
            throw parseError
        }

        guard let result = rootHandler.result else {
            throw ParseError.missingElement
        }

        return result
    }

    func parserDidStartDocument(_ parser: XMLParser) {
        do {
            try rootHandler.beginElement(attributes: [:])
        }
        catch {
            parsingError = error
            parser.abortParsing()
        }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
        guard let (_, currentHandler) = handlerStack.last else {
            parsingError = ParseError.unbalancedTags
            parser.abortParsing()
            return
        }

        do {
            var childHandler = try currentHandler.childHandler(for: elementName)

            try childHandler.beginElement(attributes: attributes)

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
            parsingError = ParseError.unbalancedTags
            parser.abortParsing()
            return
        }

        currentText += string

        textStack.append(currentText)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard let currentText = textStack.popLast(),
            let (currentTagName, elementHandler) = handlerStack.popLast(),
            elementName == currentTagName
            else {
                parsingError = ParseError.unbalancedTags
                parser.abortParsing()
                return
        }

        do {
            var mutableElementHandler = elementHandler

            try mutableElementHandler.endElement(with: currentText)
        }
        catch {
            parsingError = error
            parser.abortParsing()
        }
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        guard let currentText = textStack.popLast() else {
            parsingError = ParseError.unbalancedTags
            parser.abortParsing()
            return
        }

        do {
            try rootHandler.endElement(with: currentText)
        }
        catch {
            parsingError = error
            parser.abortParsing()
        }
    }
}
