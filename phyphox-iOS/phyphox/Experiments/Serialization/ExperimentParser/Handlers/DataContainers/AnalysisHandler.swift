//
//  AnalysisHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

enum ExperimentAnalysisDataIODescriptor {
    case value(value: Double, usedAs: String?)
    case buffer(name: String, usedAs: String?)
}

final class AnalysisDataFlowHandler: ResultElementHandler, ChildlessHandler {
    var results = [ExperimentAnalysisDataIODescriptor]()

    typealias Result = ExperimentAnalysisDataIODescriptor

    func beginElement(attributes: [String : String]) throws {
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        guard !text.isEmpty else { throw ParseError.missingText }

        let type: String = attribute("type", from: attributes, defaultValue: "buffer")
        let usedAs: String? = attribute("as", from: attributes)

        if type == "buffer" {
            results.append(.buffer(name: text, usedAs: usedAs))
        }
        else if type == "value" {
            guard let value = Double(text) else {
                throw ParseError.unreadableData
            }

            results.append(.value(value: value, usedAs: usedAs))
        }
        else {
            throw ParseError.unexpectedAttribute
        }
    }
}

struct AnalysisModuleDescriptor {
    let inputs: [ExperimentAnalysisDataIODescriptor]
    let outputs: [ExperimentAnalysisDataIODescriptor]

    let attributes: [String: String]
}

final class AnalysisModuleHandler: ResultElementHandler, LookupElementHandler, AttributelessHandler {
    typealias Result = AnalysisModuleDescriptor

    var results = [Result]()

    var handlers: [String : ElementHandler]

    private let inputsHandler = AnalysisDataFlowHandler()
    private let outputsHandler = AnalysisDataFlowHandler()

    init() {
        handlers = ["input": inputsHandler, "output": outputsHandler]
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        results.append(AnalysisModuleDescriptor(inputs: inputsHandler.results, outputs: outputsHandler.results, attributes: attributes))
    }
}

struct AnalysisDescriptor {
    let sleep: Double
    let dynamicSleepName: String?

    let modules: [(name: String, descriptor: AnalysisModuleDescriptor)]
}

final class AnalysisHandler: ResultElementHandler {
    typealias Result = AnalysisDescriptor

    var results = [Result]()

    private var handlers = [(String, AnalysisModuleHandler)]()

    func beginElement(attributes: [String : String]) throws {
    }

    func childHandler(for tagName: String) throws -> ElementHandler {
        let handler = AnalysisModuleHandler()
        handlers.append((tagName, handler))

        return handler
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        let sleep = attribute("sleep", from: attributes, defaultValue: 0.0)
        let dynamicSleep: String? = attribute("dynamicSleep", from: attributes)

        let modules = try handlers.map({ ($0.0, try $0.1.expectSingleResult()) })

        results.append(AnalysisDescriptor(sleep: sleep, dynamicSleepName: dynamicSleep, modules: modules))
    }

    func clearChildHandlers() {
        handlers.removeAll()
    }
}
