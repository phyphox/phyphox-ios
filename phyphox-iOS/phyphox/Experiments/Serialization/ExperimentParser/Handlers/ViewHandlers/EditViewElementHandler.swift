//
//  EditViewElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

struct EditViewElementDescriptor: ViewElementDescriptor {
    let label: String
    let signed: Bool
    let decimal: Bool
    let min: Double
    let max: Double
    let unit: String
    let factor: Double
    let defaultValue: Double

    let outputBufferName: String
}

final class EditViewElementHandler: ResultElementHandler, LookupElementHandler, ViewComponentElementHandler {
    typealias Result = EditViewElementDescriptor

    var results = [Result]()

    var handlers: [String : ElementHandler]

    private let outputHandler = TextElementHandler()

    init() {
        handlers = ["output": outputHandler]
    }

    func beginElement(attributes: [String: String]) throws {
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        guard let label = attributes["label"], !label.isEmpty else {
            throw XMLElementParserError.missingAttribute("label")
        }

        let outputBufferName = try outputHandler.expectSingleResult()

        let signed = try attribute("signed", from: attributes, defaultValue: true)
        let decimal = try attribute("decimal", from: attributes, defaultValue: true)
        let min = try attribute("min", from: attributes, defaultValue: -Double.infinity)
        let max = try attribute("max", from: attributes, defaultValue: Double.infinity)
        let unit = try attribute("unit", from: attributes, defaultValue: "")
        let factor = try attribute("factor", from: attributes, defaultValue: 1.0)
        let defaultValue = try attribute("default", from: attributes, defaultValue: 0.0)

        results.append(EditViewElementDescriptor(label: label, signed: signed, decimal: decimal, min: min, max: max, unit: unit, factor: factor, defaultValue: defaultValue, outputBufferName: outputBufferName))
    }

    func getResult() throws -> ViewElementDescriptor {
        return try expectSingleResult()
    }
}
