//
//  ValueViewElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class ValueViewMapElementHandler: ResultElementHandler, ChildlessElementHandler {
    typealias Result = ValueViewMap

    var results = [Result]()

    func beginElement(attributeContainer: XMLElementAttributeContainer) throws {}

    private enum Attribute: String, XMLAttributeKey {
        case min
        case max
    }

    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws {
        guard !text.isEmpty else {
            throw XMLElementParserError.missingText
        }

        let attributes = attributeContainer.attributes(keyedBy: Attribute.self)

        let min = try attributes.optionalAttribute(for: .min) ?? -Double.infinity
        let max = try attributes.optionalAttribute(for: .max) ?? Double.infinity

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
    typealias Result = ValueViewElementDescriptor

    var results = [Result]()

    var handlers: [String : ElementHandler]

    private let inputHandler = TextElementHandler()
    private let mapHandler = ValueViewMapElementHandler()

    init() {
        handlers = ["input": inputHandler, "map": mapHandler]
    }

    func beginElement(attributeContainer: XMLElementAttributeContainer) throws {}

    private enum Attribute: String, XMLAttributeKey {
        case label
        case size
        case precision
        case scientific
        case unit
        case factor
    }

    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws {
        let attributes = attributeContainer.attributes(keyedBy: Attribute.self)

        let label = try attributes.nonEmptyString(for: .label)

        let mappings = mapHandler.results
        let inpurBufferName = try inputHandler.expectSingleResult()

        let size = try attributes.optionalAttribute(for: .size) ?? 1.0
        let precision = try attributes.optionalAttribute(for: .precision) ?? 2
        let scientific = try attributes.optionalAttribute(for: .scientific) ?? false
        let unit = attributes.optionalString(for: .unit) ?? ""
        let factor = try attributes.optionalAttribute(for: .factor) ?? 1.0

        results.append(ValueViewElementDescriptor(label: label, size: size, precision: precision, scientific: scientific, unit: unit, factor: factor, inputBufferName: inpurBufferName, mappings: mappings))
    }

    func getResult() throws -> ViewElementDescriptor {
        return try expectSingleResult()
    }
}
