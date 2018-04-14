//
//  XMLElementParser.swift
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

private enum XMLElementParserError: Error {
    case parsingError(backtrace: String, encounteredError: Error)
    case missingRootElement
}

extension XMLElementParserError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .parsingError(backtrace: let backtrace, encounteredError: let error):
            return "Parser encountered error parsing element \"\(backtrace)\": \(error.localizedDescription)"
        case .missingRootElement:
            return "The root element handler returned no result"
        }
    }
}

final class XMLElementParser<Result, RootHandler: RootElementHandler>: NSObject, XMLParserDelegate where RootHandler.Result == Result {
    private var rootHandler: RootHandler

    private var handlerStack = [(String, ElementHandler)]()
    private var textStack = [String]()
    private var attributesStack = [[String: String]]()

    private var parsingError: Error?

    init(rootHandler: RootHandler) {
        self.rootHandler = rootHandler
        super.init()
    }

    private var currentElementBacktrace: String {
        return handlerStack.reduce("") { result, handler -> String in
            if result.isEmpty {
                return handler.0
            }
            else {
                return result + " > " + handler.0
            }
        }
    }

    func parse(stream: InputStream) throws -> Result {
        handlerStack = [("", rootHandler)]
        textStack = [""]
        attributesStack = [[:]]
        parsingError = nil

        let parser = XMLParser(stream: stream)
        parser.delegate = self
        parser.parse()

        if let parseError = parsingError ?? parser.parserError {
            throw XMLElementParserError.parsingError(backtrace: currentElementBacktrace, encounteredError: parseError)
        }

        guard let result = rootHandler.result else {
            throw XMLElementParserError.missingRootElement
        }

        return result
    }

    func parse(data: Data) throws -> Result {
        return try parse(stream: InputStream(data: data))
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
