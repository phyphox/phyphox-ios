//
//  AnalysisElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

enum ExperimentAnalysisDataIODescriptor {
    case value(value: Double, usedAs: String)
    case buffer(name: String, usedAs: String, clear: Bool)
    case empty(usedAs: String)
}

final class AnalysisDataFlowElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [ExperimentAnalysisDataIODescriptor]()

    typealias Result = ExperimentAnalysisDataIODescriptor

    func beginElement(attributeContainer: XMLElementAttributeContainer) throws {
    }

    private enum Attribute: String, XMLAttributeKey {
        case type
        case clear
        case usedAs = "as"
    }

    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws {
        let attributes = attributeContainer.attributes(keyedBy: Attribute.self)

        let type = attributes.optionalString(for: .type) ?? "buffer"
        let usedAs = attributes.optionalString(for: .usedAs) ?? ""

        if type == "buffer" {
            guard !text.isEmpty else { throw XMLElementParserError.missingText }

            let clear = try attributes.optionalAttribute(for: .clear) ?? true

            results.append(.buffer(name: text, usedAs: usedAs, clear: clear))
        }
        else if type == "value" {
            guard !text.isEmpty else { throw XMLElementParserError.missingText }

            guard let value = Double(text) else {
                throw XMLElementParserError.unreadableData
            }

            results.append(.value(value: value, usedAs: usedAs))
        }
        else if type == "empty" {
            results.append(.empty(usedAs: usedAs))
        }
        else {
            throw XMLElementParserError.unexpectedAttributeValue("type")
        }
    }
}

struct AnalysisModuleDescriptor {
    let inputs: [ExperimentAnalysisDataIODescriptor]
    let outputs: [ExperimentAnalysisDataIODescriptor]

    let attributes: XMLElementAttributeContainer
}

final class AnalysisModuleElementHandler: ResultElementHandler, LookupElementHandler {
    typealias Result = AnalysisModuleDescriptor

    var results = [Result]()

    var handlers: [String : ElementHandler]

    private let inputsHandler = AnalysisDataFlowElementHandler()
    private let outputsHandler = AnalysisDataFlowElementHandler()

    init() {
        handlers = ["input": inputsHandler, "output": outputsHandler]
    }

    func beginElement(attributeContainer: XMLElementAttributeContainer) throws {
    }
    
    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws {
        results.append(AnalysisModuleDescriptor(inputs: inputsHandler.results, outputs: outputsHandler.results, attributes: attributeContainer))
    }
}

struct AnalysisDescriptor {
    let sleep: Double
    let dynamicSleepName: String?

    let modules: [(name: String, descriptor: AnalysisModuleDescriptor)]
}

final class AnalysisElementHandler: ResultElementHandler {
    typealias Result = AnalysisDescriptor

    var results = [Result]()

    private var handlers = [(String, AnalysisModuleElementHandler)]()

    func beginElement(attributeContainer: XMLElementAttributeContainer) throws {
    }

    func childHandler(for tagName: String) throws -> ElementHandler {
        let handler = AnalysisModuleElementHandler()
        handlers.append((tagName, handler))

        return handler
    }

    private enum Attribute: String, XMLAttributeKey {
        case sleep
        case dynamicSleep
    }

    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws {
        let attributes = attributeContainer.attributes(keyedBy: Attribute.self)

        let sleep = try attributes.optionalAttribute(for: .sleep) ?? 0.0
        let dynamicSleep: String? = attributes.optionalString(for: .dynamicSleep)

        let modules = try handlers.map({ ($0.0, try $0.1.expectSingleResult()) })

        results.append(AnalysisDescriptor(sleep: sleep, dynamicSleepName: dynamicSleep, modules: modules))
    }

    func clearChildHandlers() {
        handlers.removeAll()
    }
}
