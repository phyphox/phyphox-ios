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

    func beginElement(attributeContainer: XMLElementAttributeContainer) throws {
    }

    // Bug in Swift 4.1 compiler (https://bugs.swift.org/browse/SR-7153). Make private again when compiling with Swift 4.2
    /*private*/ enum Attribute: String, XMLAttributeKey {
        case label
        case signed
        case decimal
        case max
        case min
        case unit
        case factor
        case defaultValue = "default"
    }

    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws {
        let attributes = attributeContainer.attributes(keyedBy: Attribute.self)

        let label = try attributes.nonEmptyAttribute(for: .label)

        let outputBufferName = try outputHandler.expectSingleResult()

        let signed = try attributes.optionalAttribute(for: .signed) ?? true
        let decimal = try attributes.optionalAttribute(for: .decimal) ?? true
        let min = try attributes.optionalAttribute(for: .min) ?? -Double.infinity
        let max = try attributes.optionalAttribute(for: .max) ?? Double.infinity
        let unit = attributes.optionalAttribute(for: .unit) ?? ""
        let factor = try attributes.optionalAttribute(for: .factor) ?? 1.0
        let defaultValue = try attributes.optionalAttribute(for: .defaultValue) ?? 0.0

        results.append(EditViewElementDescriptor(label: label, signed: signed, decimal: decimal, min: min, max: max, unit: unit, factor: factor, defaultValue: defaultValue, outputBufferName: outputBufferName))
    }

    func getResult() throws -> ViewElementDescriptor {
        return try expectSingleResult()
    }
}
