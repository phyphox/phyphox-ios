//
//  XMLFileParserHelpers.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
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
}

// TODO: localizable error

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
