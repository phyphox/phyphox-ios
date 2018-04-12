//
//  ButtonViewHandler.swift
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

private final class ButtonInputHandler: ResultElementHandler, ChildlessHandler {
    var results = [ButtonInputDescriptor]()

    typealias Result = ButtonInputDescriptor

    func beginElement(attributes: [String : String]) throws {
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        let type = attribute("type", from: attributes, defaultValue: "buffer")

        if type == "buffer" {
            guard !text.isEmpty else {
                throw ParseError.missingText
            }

            results.append(.buffer(text))
        }
        else if type == "value" {
            guard !text.isEmpty else {
                throw ParseError.missingText
            }

            guard let value = Double(text) else {
                throw ParseError.unreadableData
            }

            results.append(.value(value))
        }
        else if type == "empty" {
            results.append(.clear)
        }
        else {
            throw ParseError.unexpectedAttribute
        }
    }
}

final class ButtonViewHandler: ResultElementHandler, LookupElementHandler, ViewComponentHandler {
    typealias Result = ButtonViewElementDescriptor

    var results = [Result]()

    var handlers: [String : ElementHandler]

    private let outputHandler = TextElementHandler()
    private let inputHandler = ButtonInputHandler()

    init() {
        handlers = ["output": outputHandler, "input": inputHandler]
    }

    func beginElement(attributes: [String : String]) throws {
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        guard let label = attributes["label"], !label.isEmpty else {
            throw ParseError.missingAttribute("label")
        }

        guard inputHandler.results.count == outputHandler.results.count else {
            throw ParseError.missingElement
        }

        let dataFlow = Array(zip(inputHandler.results, outputHandler.results))

        results.append(ButtonViewElementDescriptor(label: label, dataFlow: dataFlow))
    }

    func result() throws -> ViewElementDescriptor {
        return try expectSingleResult()
    }
}
