//
//  XMLElementParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

struct XMLElementAttributes {
    fileprivate let attributes: [String: String]

    fileprivate static var empty: XMLElementAttributes {
        return XMLElementAttributes(attributes: [:])
    }

    /*fileprivate*/ init(attributes: [String: String]) {
        self.attributes = attributes
    }

    func attribute<T: LosslessStringConvertible>(for key: String) throws -> T? {
        return try attributes[key].map({
            guard let value = T.init($0) else {
                throw XMLElementParserError.unexpectedAttributeValue(key)
            }
            return value
        })
    }

    subscript(key: String) -> String? {
        get {
            return attributes[key]
        }
    }
}

protocol AttributelessElementHandler: ElementHandler {}

extension AttributelessElementHandler {
    func beginElement(attributes: XMLElementAttributes) throws {
        guard attributes.attributes.isEmpty else {
            throw XMLElementParserError.unexpectedAttribute(attributes.attributes.keys.first ?? "")
        }
    }
}

protocol ElementHandler: class {
    func beginElement(attributes: XMLElementAttributes) throws
    func childHandler(for tagName: String) throws -> ElementHandler
    func endElement(with text: String, attributes: XMLElementAttributes) throws

    func clear()
    func clearChildHandlers()
}

protocol ResultElementHandler: ElementHandler {
    associatedtype Result

    var results: [Result] { get set }
}

final class XMLElementParser<RootHandler: ResultElementHandler>: NSObject, XMLParserDelegate {
    private let rootHandler: RootHandler

    private var handlerStack = [(tagName: String, elementHandler: ElementHandler)]()
    private var textStack = [String]()
    private var attributesStack = [XMLElementAttributes]()

    private var parsingError: Error?

    init(rootHandler: RootHandler) {
        self.rootHandler = rootHandler
        super.init()
    }

    private var currentElementBacktrace: String {
        return handlerStack.map({ $0.tagName }).joined(separator: " > ")
    }

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
            try rootHandler.beginElement(attributes: attributes)
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
            let elementAttributes = XMLElementAttributes(attributes: attributes)
            try childHandler.beginElement(attributes: elementAttributes)

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
            try elementHandler.endElement(with: cleanText(currentText), attributes: attributes)
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
