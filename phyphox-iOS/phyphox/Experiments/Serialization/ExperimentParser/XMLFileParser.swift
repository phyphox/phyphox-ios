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
    mutating func endElement(with text: String, attributes: [String: String]) throws

    mutating func clear()
    mutating func clearChildHandlers()
}

protocol RootElementHandler: ElementHandler {
    associatedtype Result

    var result: Result? { get set }
}

extension RootElementHandler {
    mutating func clear() {
        result = nil
        clearChildHandlers()
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
            throw ParseError.unexpectedElement
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

protocol AttributelessHandler: ElementHandler {}

extension AttributelessHandler {
    func beginElement(attributes: [String: String]) throws {
        guard attributes.isEmpty else {
            throw ParseError.unexpectedAttribute
        }
    }
}

protocol ChildlessHandler: ElementHandler {}

extension ChildlessHandler {
    func childHandler(for tagName: String) throws -> ElementHandler {
        throw ParseError.unexpectedElement
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

final class XMLFileParser<Result, RootHandler: RootElementHandler>: NSObject, XMLParserDelegate where RootHandler.Result == Result {
    private let parser = XMLParser()

    private var rootHandler: RootHandler

    private var handlerStack: [(String, ElementHandler)]
    private var textStack = [""]
    private var attributesStack = [[String: String]]()

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
            rootHandler.clear()
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

            childHandler.clearChildHandlers()
            try childHandler.beginElement(attributes: attributes)

            attributesStack.append(attributes)
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
            let attributes = attributesStack.popLast(),
            elementName == currentTagName
            else {
                parsingError = ParseError.unbalancedTags
                parser.abortParsing()
                return
        }

        do {
            var mutableElementHandler = elementHandler

            try mutableElementHandler.endElement(with: currentText, attributes: attributes)
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
            try rootHandler.endElement(with: currentText, attributes: [:])
        }
        catch {
            parsingError = error
            parser.abortParsing()
        }
    }
}
