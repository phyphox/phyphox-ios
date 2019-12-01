//
//  ButtonViewElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

// This file contains element handlers for the `button` view element (and its child elements).

enum ButtonInputDescriptor {
    case buffer(String)
    case value(Double)
    case clear
}

struct ButtonViewElementDescriptor {
    let label: String

    let dataFlow: [(input: ButtonInputDescriptor, outputBufferName: String)]
    let triggers: [String]
}

enum DataInputTypeAttribute: String, LosslessStringConvertible {
    case buffer
    case value
    case empty
}

private final class ButtonInputElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [ButtonInputDescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case type
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let type = try attributes.optionalValue(for: .type) ?? DataInputTypeAttribute.buffer

        switch type {
        case .buffer:
            guard !text.isEmpty else {
                throw ElementHandlerError.missingText
            }

            results.append(.buffer(text))
        case .value:
            guard !text.isEmpty else {
                throw ElementHandlerError.missingText
            }

            guard let value = Double(text) else {
                throw ElementHandlerError.unexpectedAttributeValue("value")
            }

            results.append(.value(value))
        case .empty:
            results.append(.clear)
        }
    }
}

final class ButtonViewElementHandler: ResultElementHandler, LookupElementHandler, ViewComponentElementHandler {
    var results = [ViewElementDescriptor]()

    var childHandlers: [String : ElementHandler]

    private let outputHandler = TextElementHandler()
    private let inputHandler = ButtonInputElementHandler()
    private let triggerHandler = TextElementHandler()

    init() {
        childHandlers = ["output": outputHandler, "input": inputHandler, "trigger": triggerHandler]
    }

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case label
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let label = attributes.optionalString(for: .label) ?? ""

        guard inputHandler.results.count == outputHandler.results.count else {
            throw ElementHandlerError.missingChildElement(inputHandler.results.count > outputHandler.results.count ? "output" : "input")
        }

        let dataFlow = Array(zip(inputHandler.results, outputHandler.results))
        let triggers = triggerHandler.results

        results.append(.button(ButtonViewElementDescriptor(label: label, dataFlow: dataFlow, triggers: triggers)))
    }

    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}
