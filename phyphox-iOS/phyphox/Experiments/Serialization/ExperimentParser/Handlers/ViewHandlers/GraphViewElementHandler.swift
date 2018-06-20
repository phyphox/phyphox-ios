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

    func beginElement(attributeContainer: XMLElementAttributeContainer) throws {
    }

    private enum Attribute: String, XMLAttributeKey {
        case axis
    }

    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws {
        guard !text.isEmpty else {
            throw XMLElementParserError.missingText
        }

        let attributes = attributeContainer.attributes(keyedBy: Attribute.self)

        let axis: GraphAxis = try attributes.attribute(for: .axis)

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

    func beginElement(attributeContainer: XMLElementAttributeContainer) throws {}

    private enum Attribute: String, XMLAttributeKey {
        case label
        case labelX
        case labelY
        case aspectRatio
        case style
        case partialUpdate
        case history
        case lineWidth
        case color
        case logX
        case logY
        case xPrecision
        case yPrecision
        case scaleMinX
        case scaleMaxX
        case scaleMinY
        case scaleMaxY
        case minX
        case maxX
        case minY
        case maxY
    }
    
    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws {
        let attributes = attributeContainer.attributes(keyedBy: Attribute.self)

        let label = try attributes.nonEmptyString(for: .label)
        let xLabel = try attributes.nonEmptyString(for: .labelX)
        let yLabel = try attributes.nonEmptyString(for: .labelY)

        guard let yInputBufferName = inputHandler.results.first(where: { $0.axis == .y })?.bufferName else {
            throw XMLElementParserError.missingElement("data-container")
        }

        let xInputBufferName = inputHandler.results.first(where: { $0.axis == .x })?.bufferName

        let aspectRatio: CGFloat = try attributes.optionalAttribute(for: .aspectRatio) ?? 2.5
        let dots = attributes.optionalString(for: .style) ?? "line" == "dots"
        let partialUpdate = try attributes.optionalAttribute(for: .partialUpdate) ?? false
        let history: UInt = try attributes.optionalAttribute(for: .history) ?? 1
        let lineWidth: CGFloat = try attributes.optionalAttribute(for: .lineWidth) ?? 1.0
        let colorString: String? = attributes.optionalString(for: .color)

        let color = try colorString.map({ string -> UIColor in
            guard let color = UIColor(hexString: string) else {
                throw XMLElementParserError.unexpectedAttributeValue("color")
            }

            return color
        }) ?? kHighlightColor

        let logX = try attributes.optionalAttribute(for: .logX) ?? false
        let logY = try attributes.optionalAttribute(for: .logY) ?? false
        let xPrecision: UInt = try attributes.optionalAttribute(for: .xPrecision) ?? 3
        let yPrecision: UInt = try attributes.optionalAttribute(for: .yPrecision) ?? 3

        let scaleMinX: GraphViewDescriptor.ScaleMode = try attributes.optionalAttribute(for: .scaleMinX) ?? .auto
        let scaleMaxX: GraphViewDescriptor.ScaleMode = try attributes.optionalAttribute(for: .scaleMaxX) ?? .auto
        let scaleMinY: GraphViewDescriptor.ScaleMode = try attributes.optionalAttribute(for: .scaleMinY) ?? .auto
        let scaleMaxY: GraphViewDescriptor.ScaleMode = try attributes.optionalAttribute(for: .scaleMaxY) ?? .auto

        let minX: CGFloat = try attributes.optionalAttribute(for: .minX) ?? 0
        let maxX: CGFloat = try attributes.optionalAttribute(for: .maxX) ?? 0
        let minY: CGFloat = try attributes.optionalAttribute(for: .minY) ?? 0
        let maxY: CGFloat = try attributes.optionalAttribute(for: .maxY) ?? 0

        results.append(GraphViewElementDescriptor(label: label, xLabel: xLabel, yLabel: yLabel, logX: logX, logY: logY, xPrecision: xPrecision, yPrecision: yPrecision, minX: minX, maxX: maxX, minY: minY, maxY: maxY, scaleMinX: scaleMinX, scaleMaxX: scaleMaxX, scaleMinY: scaleMinY, scaleMaxY: scaleMaxY, xInputBufferName: xInputBufferName, yInputBufferName: yInputBufferName, aspectRatio: aspectRatio, partialUpdate: partialUpdate, drawDots: dots, history: history, lineWidth: lineWidth, color: color))
    }

    func getResult() throws -> ViewElementDescriptor {
        return try expectSingleResult()
    }
}
