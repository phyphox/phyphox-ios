//
//  XMLFileParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

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

final class XMLFileParser<Result, RootHandler: RootElementHandler>: NSObject, XMLParserDelegate where RootHandler.Result == Result {
    private var rootHandler: RootHandler

    private var handlerStack = [(String, ElementHandler)]()
    private var textStack = [String]()
    private var attributesStack = [[String: String]]()

    private var parsingError: Error?

    init(rootHandler: RootHandler) {
        self.rootHandler = rootHandler
        super.init()
    }

    func parse(data: Data) throws -> Result {
        handlerStack = [("", rootHandler)]
        textStack = [""]
        attributesStack = [[:]]

        let parser = XMLParser(data: data)
        parser.delegate = self

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

    private func cleanText(_ textToClean: String) -> String {
        return textToClean.trimmingCharacters(in: .whitespacesAndNewlines)
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

            try mutableElementHandler.endElement(with: cleanText(currentText), attributes: attributes)
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
                parsingError = ParseError.unbalancedTags
                parser.abortParsing()
                return
        }
        
        do {
            try rootHandler.endElement(with: cleanText(currentText), attributes: attributes)
        }
        catch {
            parsingError = error
            parser.abortParsing()
        }
    }
}
