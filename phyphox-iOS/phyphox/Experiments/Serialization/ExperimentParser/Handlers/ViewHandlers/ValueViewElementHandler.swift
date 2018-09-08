//
//  ValueViewElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

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

struct ValueViewElementDescriptor: ViewElementDescriptor {
    let label: String
    let size: Double
    let precision: Int
    let scientific: Bool
    let unit: String
    let factor: Double

    let inputBufferName: String
    let mappings: [ValueViewMap]
}

final class ValueViewElementHandler: ResultElementHandler, LookupElementHandler, ViewComponentElementHandler {
    var results = [ValueViewElementDescriptor]()

    var childHandlers: [String: ElementHandler]

    private let inputHandler = TextElementHandler()
    private let mapHandler = ValueViewMapElementHandler()

    init() {
        childHandlers = ["input": inputHandler, "map": mapHandler]
    }

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case label
        case size
        case precision
        case scientific
        case unit
        case factor
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let label = try attributes.nonEmptyString(for: .label)

        let mappings = mapHandler.results
        let inpurBufferName = try inputHandler.expectSingleResult()

        let size = try attributes.optionalValue(for: .size) ?? 1.0
        let precision = try attributes.optionalValue(for: .precision) ?? 2
        let scientific = try attributes.optionalValue(for: .scientific) ?? false
        let unit = attributes.optionalString(for: .unit) ?? ""
        let factor = try attributes.optionalValue(for: .factor) ?? 1.0

        results.append(ValueViewElementDescriptor(label: label, size: size, precision: precision, scientific: scientific, unit: unit, factor: factor, inputBufferName: inpurBufferName, mappings: mappings))
    }

    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}
