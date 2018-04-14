//
//  GraphViewElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

private enum GraphAxis: String {
    case x
    case y
}

private struct GraphInputDescriptor {
    let axis: GraphAxis
    let bufferName: String
}

extension CGFloat: LosslessStringConvertible {
    public init?(_ description: String) {
        guard let double = Double(description) else { return nil }

        self.init(double)
    }
}

private final class GraphInputElementHandler: ResultElementHandler, ChildlessElementHandler {
    typealias Result = GraphInputDescriptor

    var results = [GraphInputDescriptor]()

    func beginElement(attributes: [String: String]) throws {
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        guard !text.isEmpty else {
            throw XMLElementParserError.missingText
        }

        guard let axis = (attributes["axis"].map({ GraphAxis(rawValue: $0) }) ?? nil) else {
            throw XMLElementParserError.missingAttribute("axis")
        }

        results.append(GraphInputDescriptor(axis: axis, bufferName: text))
    }
}

struct GraphViewElementDescriptor: ViewElementDescriptor {
    let label: String
    
    let xLabel: String
    let yLabel: String

    let logX: Bool
    let logY: Bool

    let xPrecision: UInt
    let yPrecision: UInt

    let minX: CGFloat
    let maxX: CGFloat
    let minY: CGFloat
    let maxY: CGFloat

    let scaleMinX: GraphViewDescriptor.ScaleMode
    let scaleMaxX: GraphViewDescriptor.ScaleMode
    let scaleMinY: GraphViewDescriptor.ScaleMode
    let scaleMaxY: GraphViewDescriptor.ScaleMode

    var xInputBufferName: String?
    var yInputBufferName: String

    let aspectRatio: CGFloat
    let partialUpdate: Bool
    let drawDots: Bool
    let history: UInt

    let lineWidth: CGFloat
    let color: UIColor
}

final class GraphViewElementHandler: ResultElementHandler, LookupElementHandler, ViewComponentElementHandler {
    typealias Result = GraphViewElementDescriptor

    var results = [Result]()

    var handlers: [String : ElementHandler]

    private let inputHandler = GraphInputElementHandler()

    init() {
        handlers = ["input": inputHandler]
    }

    func beginElement(attributes: [String: String]) throws {
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        guard let label = attributes["label"], !label.isEmpty else {
            throw XMLElementParserError.missingAttribute("label")
        }

        guard let xLabel = attributes["labelX"], !xLabel.isEmpty else {
            throw XMLElementParserError.missingAttribute("labelX")
        }

        guard let yLabel = attributes["labelY"], !yLabel.isEmpty else {
            throw XMLElementParserError.missingAttribute("labelY")
        }

        guard let yInputBufferName = inputHandler.results.first(where: { $0.axis == .y })?.bufferName else {
            throw XMLElementParserError.missingElement("data-container")
        }

        let xInputBufferName = inputHandler.results.first(where: { $0.axis == .x })?.bufferName

        let aspectRatio: CGFloat = try attribute("aspectRatio", from: attributes, defaultValue: 2.5)
        let dots = try attribute("style", from: attributes, defaultValue: "line") == "dots"
        let partialUpdate = try attribute("partialUpdate", from: attributes, defaultValue: false)
        let history: UInt = try attribute("history", from: attributes, defaultValue: 1)
        let lineWidth: CGFloat = try attribute("lineWidth", from: attributes, defaultValue: 1.0)
        let colorString: String? = try attribute("color", from: attributes)

        let color = try colorString.map({ string -> UIColor in
            guard let color = UIColor(hexString: string) else {
                throw XMLElementParserError.unexpectedAttributeValue("color")
            }

            return color
        }) ?? kHighlightColor

        let logX = try attribute("logX", from: attributes, defaultValue: false)
        let logY = try attribute("logY", from: attributes, defaultValue: false)
        let xPrecision: UInt = try attribute("xPrecision", from: attributes, defaultValue: 3)
        let yPrecision: UInt = try attribute("yPrecision", from: attributes, defaultValue: 3)

        guard let scaleMinX = GraphViewDescriptor.ScaleMode(rawValue: try attribute("scaleMinX", from: attributes, defaultValue: "auto")),
            let scaleMaxX = GraphViewDescriptor.ScaleMode(rawValue: try attribute("scaleMaxX", from: attributes, defaultValue: "auto")),
            let scaleMinY = GraphViewDescriptor.ScaleMode(rawValue: try attribute("scaleMinY", from: attributes, defaultValue: "auto")),
            let scaleMaxY = GraphViewDescriptor.ScaleMode(rawValue: try attribute("scaleMaxY", from: attributes, defaultValue: "auto"))
            else {
                throw XMLElementParserError.unexpectedAttributeValue("scale")
        }

        let minX: CGFloat = try attribute("minX", from: attributes, defaultValue: 0)
        let maxX: CGFloat = try attribute("maxX", from: attributes, defaultValue: 0)
        let minY: CGFloat = try attribute("minY", from: attributes, defaultValue: 0)
        let maxY: CGFloat = try attribute("maxY", from: attributes, defaultValue: 0)

        results.append(GraphViewElementDescriptor(label: label, xLabel: xLabel, yLabel: yLabel, logX: logX, logY: logY, xPrecision: xPrecision, yPrecision: yPrecision, minX: minX, maxX: maxX, minY: minY, maxY: maxY, scaleMinX: scaleMinX, scaleMaxX: scaleMaxX, scaleMinY: scaleMinY, scaleMaxY: scaleMaxY, xInputBufferName: xInputBufferName, yInputBufferName: yInputBufferName, aspectRatio: aspectRatio, partialUpdate: partialUpdate, drawDots: dots, history: history, lineWidth: lineWidth, color: color))
    }

    func getResult() throws -> ViewElementDescriptor {
        return try expectSingleResult()
    }
}
