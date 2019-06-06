//
//  ValueViewElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

// This file contains element handlers for the `value` view element (and its child elements).

final class ValueViewMapElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [ValueViewMap]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case min
        case max
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        guard !text.isEmpty else {
            throw ElementHandlerError.missingText
        }

        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let min = try attributes.optionalValue(for: .min) ?? -Double.infinity
        let max = try attributes.optionalValue(for: .max) ?? Double.infinity

        results.append(ValueViewMap(range: min...max, replacement: text))
    }
}

struct ValueViewElementDescriptor {
    let label: String
    let color: UIColor
    let size: Double
    let precision: Int
    let scientific: Bool
    let unit: String
    let factor: Double

    let inputBufferName: String
    let mappings: [ValueViewMap]
}

final class ValueViewElementHandler: ResultElementHandler, LookupElementHandler, ViewComponentElementHandler {
    var results = [ViewElementDescriptor]()

    var childHandlers: [String: ElementHandler]

    private let inputHandler = TextElementHandler()
    private let mapHandler = ValueViewMapElementHandler()

    init() {
        childHandlers = ["input": inputHandler, "map": mapHandler]
    }

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case label
        case color
        case size
        case precision
        case scientific
        case unit
        case factor
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let label = attributes.optionalString(for: .label) ?? ""
        let color = mapColorString(attributes.optionalString(for: .color)) ?? kTextColor

        let mappings = mapHandler.results
        let inpurBufferName = try inputHandler.expectSingleResult()

        let size = try attributes.optionalValue(for: .size) ?? 1.0
        let precision = try attributes.optionalValue(for: .precision) ?? 2
        let scientific = try attributes.optionalValue(for: .scientific) ?? false
        let unit = attributes.optionalString(for: .unit) ?? ""
        let factor = try attributes.optionalValue(for: .factor) ?? 1.0

        results.append(.value(ValueViewElementDescriptor(label: label, color: color, size: size, precision: precision, scientific: scientific, unit: unit, factor: factor, inputBufferName: inpurBufferName, mappings: mappings)))
    }

    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}
