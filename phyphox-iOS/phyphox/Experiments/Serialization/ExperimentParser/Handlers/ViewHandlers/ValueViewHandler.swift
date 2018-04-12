//
//  ValueViewHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class ValueViewMapHandler: ResultElementHandler, ChildlessHandler {
    typealias Result = ValueViewMap

    var results = [Result]()

    func beginElement(attributes: [String : String]) throws {
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        guard !text.isEmpty else {
            throw ParseError.missingText
        }

        let min = attribute("min", from: attributes, defaultValue: -Double.infinity)
        let max = attribute("max", from: attributes, defaultValue: Double.infinity)

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

final class ValueViewHandler: ResultElementHandler, LookupElementHandler, ViewComponentHandler {
    typealias Result = ValueViewElementDescriptor

    var results = [Result]()

    var handlers: [String : ElementHandler]

    private let inputHandler = TextElementHandler()
    private let mapHandler = ValueViewMapHandler()

    init() {
        handlers = ["input": inputHandler, "map": mapHandler]
    }

    func beginElement(attributes: [String : String]) throws {
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        guard let label = attributes["label"], !label.isEmpty else {
            throw ParseError.missingAttribute("label")
        }

        let mappings = mapHandler.results
        let inpurBufferName = try inputHandler.expectSingleResult()

        let size = attribute("size", from: attributes, defaultValue: 1.0)
        let precision = attribute("precision", from: attributes, defaultValue: 2)
        let scientific = attribute("scientific", from: attributes, defaultValue: false)
        let unit = attribute("unit", from: attributes, defaultValue: "")
        let factor = attribute("factor", from: attributes, defaultValue: 1.0)

        results.append(ValueViewElementDescriptor(label: label, size: size, precision: precision, scientific: scientific, unit: unit, factor: factor, inputBufferName: inpurBufferName, mappings: mappings))
    }

    func result() throws -> ViewElementDescriptor {
        return try expectSingleResult()
    }
}
