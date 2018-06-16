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

    func beginElement(attributes: XMLElementAttributes) throws {
    }

    func endElement(with text: String, attributes: XMLElementAttributes) throws {
        guard let label = attributes["label"], !label.isEmpty else {
            throw XMLElementParserError.missingAttribute("label")
        }

        let outputBufferName = try outputHandler.expectSingleResult()

        let signed = try attributes.attribute(for: "signed") ?? true
        let decimal = try attributes.attribute(for: "decimal") ?? true
        let min = try attributes.attribute(for: "min") ?? -Double.infinity
        let max = try attributes.attribute(for: "max") ?? Double.infinity
        let unit = try attributes.attribute(for: "unit") ?? ""
        let factor = try attributes.attribute(for: "factor") ?? 1.0
        let defaultValue = try attributes.attribute(for: "default") ?? 0.0

        results.append(EditViewElementDescriptor(label: label, signed: signed, decimal: decimal, min: min, max: max, unit: unit, factor: factor, defaultValue: defaultValue, outputBufferName: outputBufferName))
    }

    func getResult() throws -> ViewElementDescriptor {
        return try expectSingleResult()
    }
}
