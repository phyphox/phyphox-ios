//
//  ButtonViewElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

enum ButtonInputDescriptor {
    case buffer(String)
    case value(Double)
    case clear
}

struct ButtonViewElementDescriptor: ViewElementDescriptor {
    let label: String

    let dataFlow: [(input: ButtonInputDescriptor, outputBufferName: String)]
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
    var results = [ButtonViewElementDescriptor]()

    var childHandlers: [String : ElementHandler]

    private let outputHandler = TextElementHandler()
    private let inputHandler = ButtonInputElementHandler()

    init() {
        childHandlers = ["output": outputHandler, "input": inputHandler]
    }

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case label
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let label = try attributes.nonEmptyString(for: .label)

        guard inputHandler.results.count == outputHandler.results.count else {
            throw ElementHandlerError.missingChildElement(inputHandler.results.count > outputHandler.results.count ? "output" : "input")
        }

        let dataFlow = Array(zip(inputHandler.results, outputHandler.results))

        results.append(ButtonViewElementDescriptor(label: label, dataFlow: dataFlow))
    }

    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}
