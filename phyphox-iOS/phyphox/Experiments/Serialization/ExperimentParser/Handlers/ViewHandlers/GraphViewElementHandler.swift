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

    func beginElement(attributes: XMLElementAttributes) throws {
    }

    func endElement(with text: String, attributes: XMLElementAttributes) throws {
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

    func beginElement(attributes: XMLElementAttributes) throws {
    }

    func endElement(with text: String, attributes: XMLElementAttributes) throws {
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

        let aspectRatio: CGFloat = try attributes.attribute(for: "aspectRatio") ?? 2.5
        let dots = try attributes.attribute(for: "style") ?? "line" == "dots"
        let partialUpdate = try attributes.attribute(for: "partialUpdate") ?? false
        let history: UInt = try attributes.attribute(for: "history") ?? 1
        let lineWidth: CGFloat = try attributes.attribute(for: "lineWidth") ?? 1.0
        let colorString: String? = try attributes.attribute(for: "color")

        let color = try colorString.map({ string -> UIColor in
            guard let color = UIColor(hexString: string) else {
                throw XMLElementParserError.unexpectedAttributeValue("color")
            }

            return color
        }) ?? kHighlightColor

        let logX = try attributes.attribute(for: "logX") ?? false
        let logY = try attributes.attribute(for: "logY") ?? false
        let xPrecision: UInt = try attributes.attribute(for: "xPrecision") ?? 3
        let yPrecision: UInt = try attributes.attribute(for: "yPrecision") ?? 3

        guard let scaleMinX = GraphViewDescriptor.ScaleMode(rawValue: try attributes.attribute(for: "scaleMinX") ?? "auto"),
            let scaleMaxX = GraphViewDescriptor.ScaleMode(rawValue: try attributes.attribute(for: "scaleMaxX") ?? "auto"),
            let scaleMinY = GraphViewDescriptor.ScaleMode(rawValue: try attributes.attribute(for: "scaleMinY") ?? "auto"),
            let scaleMaxY = GraphViewDescriptor.ScaleMode(rawValue: try attributes.attribute(for: "scaleMaxY") ?? "auto")
            else {
                throw XMLElementParserError.unexpectedAttributeValue("scale")
        }

        let minX: CGFloat = try attributes.attribute(for: "minX") ?? 0
        let maxX: CGFloat = try attributes.attribute(for: "maxX") ?? 0
        let minY: CGFloat = try attributes.attribute(for: "minY") ?? 0
        let maxY: CGFloat = try attributes.attribute(for: "maxY") ?? 0

        results.append(GraphViewElementDescriptor(label: label, xLabel: xLabel, yLabel: yLabel, logX: logX, logY: logY, xPrecision: xPrecision, yPrecision: yPrecision, minX: minX, maxX: maxX, minY: minY, maxY: maxY, scaleMinX: scaleMinX, scaleMaxX: scaleMaxX, scaleMinY: scaleMinY, scaleMaxY: scaleMaxY, xInputBufferName: xInputBufferName, yInputBufferName: yInputBufferName, aspectRatio: aspectRatio, partialUpdate: partialUpdate, drawDots: dots, history: history, lineWidth: lineWidth, color: color))
    }

    func getResult() throws -> ViewElementDescriptor {
        return try expectSingleResult()
    }
}
