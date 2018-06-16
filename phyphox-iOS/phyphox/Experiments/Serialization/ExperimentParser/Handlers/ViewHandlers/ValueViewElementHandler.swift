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

    func beginElement(attributes: XMLElementAttributes) throws {
    }

    func endElement(with text: String, attributes: XMLElementAttributes) throws {
        guard !text.isEmpty else {
            throw XMLElementParserError.missingText
        }

        let min = try attributes.attribute(for: "min") ?? -Double.infinity
        let max = try attributes.attribute(for: "max") ?? Double.infinity

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

    func beginElement(attributes: XMLElementAttributes) throws {
    }

    func endElement(with text: String, attributes: XMLElementAttributes) throws {
        guard let label = attributes["label"], !label.isEmpty else {
            throw XMLElementParserError.missingAttribute("label")
        }

        let mappings = mapHandler.results
        let inpurBufferName = try inputHandler.expectSingleResult()

        let size = try attributes.attribute(for: "size") ?? 1.0
        let precision = try attributes.attribute(for: "precision") ?? 2
        let scientific = try attributes.attribute(for: "scientific") ?? false
        let unit = try attributes.attribute(for: "unit") ?? ""
        let factor = try attributes.attribute(for: "factor") ?? 1.0

        results.append(ValueViewElementDescriptor(label: label, size: size, precision: precision, scientific: scientific, unit: unit, factor: factor, inputBufferName: inpurBufferName, mappings: mappings))
    }

    func getResult() throws -> ViewElementDescriptor {
        return try expectSingleResult()
    }
}
