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

enum DataTypeAttribute: String {
    case buffer
    case value
    case empty
}

private final class ButtonInputElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [ButtonInputDescriptor]()

    typealias Result = ButtonInputDescriptor

    func beginElement(attributeContainer: XMLElementAttributeContainer) throws {}

    // Bug in Swift 4.1 compiler (https://bugs.swift.org/browse/SR-7153). Make private again when compiling with Swift 4.2
    /*private*/ enum Attribute: String, XMLAttributeKey {
        case type
    }

    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws {
        let attributes = attributeContainer.attributes(keyedBy: Attribute.self)

        let type = try attributes.optionalAttribute(for: .type) ?? DataTypeAttribute.buffer

        switch type {
        case .buffer:
            guard !text.isEmpty else {
                throw XMLElementParserError.missingText
            }

            results.append(.buffer(text))
        case .value:
            guard !text.isEmpty else {
                throw XMLElementParserError.missingText
            }

            guard let value = Double(text) else {
                throw XMLElementParserError.unexpectedAttributeValue("value")
            }

            results.append(.value(value))
        case .empty:
            results.append(.clear)
        }
    }
}

final class ButtonViewElementHandler: ResultElementHandler, LookupElementHandler, ViewComponentElementHandler {
    typealias Result = ButtonViewElementDescriptor

    var results = [Result]()

    var handlers: [String : ElementHandler]

    private let outputHandler = TextElementHandler()
    private let inputHandler = ButtonInputElementHandler()

    init() {
        handlers = ["output": outputHandler, "input": inputHandler]
    }

    func beginElement(attributeContainer: XMLElementAttributeContainer) throws {
    }

    // Bug in Swift 4.1 compiler (https://bugs.swift.org/browse/SR-7153). Make private again when compiling with Swift 4.2
    /*private*/ enum Attribute: String, XMLAttributeKey {
        case label
    }

    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws {
        let attributes = attributeContainer.attributes(keyedBy: Attribute.self)

        let label = try attributes.nonEmptyAttribute(for: .label)

        guard inputHandler.results.count == outputHandler.results.count else {
            throw XMLElementParserError.missingChildElement(inputHandler.results.count > outputHandler.results.count ? "output" : "input")
        }

        let dataFlow = Array(zip(inputHandler.results, outputHandler.results))

        results.append(ButtonViewElementDescriptor(label: label, dataFlow: dataFlow))
    }

    func getResult() throws -> ViewElementDescriptor {
        return try expectSingleResult()
    }
}
