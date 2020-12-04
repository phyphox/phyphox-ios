//
//  AnalysisElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

// This file contains element handlers for the `analysis` child element (and its child elements) of the `phyphox` root element.

enum ExperimentAnalysisDataIODescriptor {
    case value(value: Double, usedAs: String)
    case buffer(name: String, usedAs: String, clear: Bool)
    case empty(usedAs: String)
}

final class AnalysisDataFlowElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [ExperimentAnalysisDataIODescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case type
        case clear
        case usedAs = "as"
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let type = try attributes.optionalValue(for: .type) ?? DataInputTypeAttribute.buffer
        let usedAs = attributes.optionalString(for: .usedAs) ?? ""

        switch type {
        case .buffer:
            guard !text.isEmpty else { throw ElementHandlerError.missingText }

            let clear = try attributes.optionalValue(for: .clear) ?? true

            results.append(.buffer(name: text, usedAs: usedAs, clear: clear))
        case .value:
            guard !text.isEmpty else { throw ElementHandlerError.missingText }

            guard let value = Double(text) else {
                throw ElementHandlerError.unreadableData
            }

            results.append(.value(value: value, usedAs: usedAs))
        case .empty:
            results.append(.empty(usedAs: usedAs))
        }
    }
}

struct AnalysisModuleDescriptor {
    let inputs: [ExperimentAnalysisDataIODescriptor]
    let outputs: [ExperimentAnalysisDataIODescriptor]

    let attributes: AttributeContainer
}

final class AnalysisModuleElementHandler: ResultElementHandler, LookupElementHandler {
    typealias Result = AnalysisModuleDescriptor

    var results = [Result]()

    var childHandlers: [String : ElementHandler]

    private let inputsHandler = AnalysisDataFlowElementHandler()
    private let outputsHandler = AnalysisDataFlowElementHandler()

    init() {
        childHandlers = ["input": inputsHandler, "output": outputsHandler]
    }

    func startElement(attributes: AttributeContainer) throws {}
    
    func endElement(text: String, attributes: AttributeContainer) throws {
        results.append(AnalysisModuleDescriptor(inputs: inputsHandler.results, outputs: outputsHandler.results, attributes: attributes))
    }
}

struct AnalysisDescriptor {
    let sleep: Double
    let dynamicSleepName: String?
    let onUserInput: Bool

    let timedRun: Bool
    let timedRunStartDelay: Double
    let timedRunStopDelay: Double
    
    let modules: [(name: String, descriptor: AnalysisModuleDescriptor)]
}

final class AnalysisElementHandler: ResultElementHandler {
    typealias Result = AnalysisDescriptor

    var results = [Result]()

    private var moduleNames = [String]()
    private let moduleHandler = AnalysisModuleElementHandler()

    func startElement(attributes: AttributeContainer) throws {}

    func childHandler(for elementName: String) throws -> ElementHandler {
        moduleNames.append(elementName)
        return moduleHandler
    }

    private enum Attribute: String, AttributeKey {
        case sleep
        case dynamicSleep
        case onUserInput
        case timedRun
        case timedRunStartDelay
        case timedRunStopDelay
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let sleep = try attributes.optionalValue(for: .sleep) ?? 0.0
        let dynamicSleep: String? = attributes.optionalString(for: .dynamicSleep)
        
        let onUserInput: Bool = try attributes.optionalValue(for: .onUserInput) ?? false
        
        let timedRun = try attributes.optionalValue(for: .timedRun) ?? false
        let timedRunStartDelay = try attributes.optionalValue(for: .timedRunStartDelay) ?? 3.0
        let timedRunStopDelay = try attributes.optionalValue(for: .timedRunStopDelay) ?? 10.0
        
        guard moduleNames.count == moduleHandler.results.count else {
            throw ElementHandlerError.message("Unparsed Analysis Module")
        }

        let modules = Array(zip(moduleNames, moduleHandler.results))

        results.append(AnalysisDescriptor(sleep: sleep, dynamicSleepName: dynamicSleep, onUserInput: onUserInput, timedRun: timedRun, timedRunStartDelay: timedRunStartDelay, timedRunStopDelay: timedRunStopDelay, modules: modules))
    }

    func clearChildHandlers() {
        moduleNames.removeAll()
        moduleHandler.clear()
    }
}
