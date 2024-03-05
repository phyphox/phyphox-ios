//
//  AnalysisElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

// This file contains element handlers for the `analysis` child element (and its child elements) of the `phyphox` root element.

enum ExperimentAnalysisDataInputDescriptor {
    case value(value: Double, usedAs: String)
    case buffer(name: String, usedAs: String, keep: Bool)
    case empty(usedAs: String)
}

enum ExperimentAnalysisDataOutputDescriptor {
    case buffer(name: String, usedAs: String, append: Bool)
}

final class AnalysisDataInputElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [ExperimentAnalysisDataInputDescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case type
        case clear
        case keep
        case usedAs = "as"
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let type = try attributes.optionalValue(for: .type) ?? DataInputTypeAttribute.buffer
        let usedAs = attributes.optionalString(for: .usedAs) ?? ""

        switch type {
        case .buffer:
            guard !text.isEmpty else { throw ElementHandlerError.missingText }

            let clear = try attributes.optionalValue(for: .clear) ?? true //deprecated
            let keep = try attributes.optionalValue(for: .keep) ?? !clear
            
            results.append(.buffer(name: text, usedAs: usedAs, keep: keep))
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

final class AnalysisDataOutputElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [ExperimentAnalysisDataOutputDescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case type
        case clear
        case append
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
            let append = try attributes.optionalValue(for: .append) ?? !clear
            
            results.append(.buffer(name: text, usedAs: usedAs, append: append))
        case .value:
            throw ElementHandlerError.unexpectedAttributeValue("type")
        case .empty:
            throw ElementHandlerError.unexpectedAttributeValue("type")
        }
    }
}

struct AnalysisModuleDescriptor {
    let inputs: [ExperimentAnalysisDataInputDescriptor]
    let outputs: [ExperimentAnalysisDataOutputDescriptor]

    let attributes: AttributeContainer
}

final class AnalysisModuleElementHandler: ResultElementHandler, LookupElementHandler {
    typealias Result = AnalysisModuleDescriptor

    var results = [Result]()

    var childHandlers: [String : ElementHandler]

    private let inputsHandler = AnalysisDataInputElementHandler()
    private let outputsHandler = AnalysisDataOutputElementHandler()

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

    let requireFillName: String?
    let requireFillThreshold: Int
    let requireFillDynamicName: String?
    
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
        case requireFill
        case requireFillThreshold
        case requireFillDynamic
        case timedRun
        case timedRunStartDelay
        case timedRunStopDelay
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let sleep = try attributes.optionalValue(for: .sleep) ?? 0.0
        let dynamicSleep: String? = attributes.optionalString(for: .dynamicSleep)
        
        let onUserInput: Bool = try attributes.optionalValue(for: .onUserInput) ?? false
        
        let requireFillName: String? = attributes.optionalString(for: .requireFill)
        let requireFillThreshold = try attributes.optionalValue(for: .requireFillThreshold) ?? 1
        let requireFillDynamicName = attributes.optionalString(for: .requireFillDynamic)
        
        let timedRun = try attributes.optionalValue(for: .timedRun) ?? false
        let timedRunStartDelay = try attributes.optionalValue(for: .timedRunStartDelay) ?? 3.0
        let timedRunStopDelay = try attributes.optionalValue(for: .timedRunStopDelay) ?? 10.0
        
        guard moduleNames.count == moduleHandler.results.count else {
            throw ElementHandlerError.message("Unparsed Analysis Module")
        }

        let modules = Array(zip(moduleNames, moduleHandler.results))

        results.append(AnalysisDescriptor(sleep: sleep, dynamicSleepName: dynamicSleep, onUserInput: onUserInput, requireFillName: requireFillName, requireFillThreshold: requireFillThreshold, requireFillDynamicName: requireFillDynamicName, timedRun: timedRun, timedRunStartDelay: timedRunStartDelay, timedRunStopDelay: timedRunStopDelay, modules: modules))
    }

    func clearChildHandlers() {
        moduleNames.removeAll()
        moduleHandler.clear()
    }
}
