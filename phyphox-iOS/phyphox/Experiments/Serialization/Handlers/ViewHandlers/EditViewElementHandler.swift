//
//  EditViewElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

// This file contains element handlers for the `edit` view element (and its child elements).

struct EditViewElementDescriptor {
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
    var results = [ViewElementDescriptor]()

    var childHandlers: [String : ElementHandler]

    private let outputHandler = TextElementHandler()

    init() {
        childHandlers = ["output": outputHandler]
    }

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case label
        case signed
        case decimal
        case max
        case min
        case unit
        case factor
        case defaultValue = "default"
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let label = attributes.optionalString(for: .label) ?? ""

        let outputBufferName = try outputHandler.expectSingleResult()

        let signed = try attributes.optionalValue(for: .signed) ?? true
        let decimal = try attributes.optionalValue(for: .decimal) ?? true
        let min = try attributes.optionalValue(for: .min) ?? -Double.infinity
        let max = try attributes.optionalValue(for: .max) ?? Double.infinity
        let unit = attributes.optionalString(for: .unit) ?? ""
        let factor = try attributes.optionalValue(for: .factor) ?? 1.0
        let defaultValue = try attributes.optionalValue(for: .defaultValue) ?? 0.0

        results.append(.edit(EditViewElementDescriptor(label: label, signed: signed, decimal: decimal, min: min, max: max, unit: unit, factor: factor, defaultValue: defaultValue, outputBufferName: outputBufferName)))
    }

    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}
