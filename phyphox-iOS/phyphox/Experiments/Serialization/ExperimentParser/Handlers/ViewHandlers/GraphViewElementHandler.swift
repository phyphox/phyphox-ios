//
//  GraphViewElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

private enum GraphAxis: String, LosslessStringConvertible {
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
    var results = [GraphInputDescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case axis
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        guard !text.isEmpty else {
            throw ElementHandlerError.missingText
        }

        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let axis: GraphAxis = try attributes.value(for: .axis)

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
    var results = [GraphViewElementDescriptor]()

    var childHandlers: [String : ElementHandler]

    private let inputHandler = GraphInputElementHandler()

    init() {
        childHandlers = ["input": inputHandler]
    }

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
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
    
    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let label = try attributes.nonEmptyString(for: .label)
        let xLabel = try attributes.nonEmptyString(for: .labelX)
        let yLabel = try attributes.nonEmptyString(for: .labelY)

        guard let yInputBufferName = inputHandler.results.first(where: { $0.axis == .y })?.bufferName else {
            throw ElementHandlerError.missingElement("data-container")
        }

        let xInputBufferName = inputHandler.results.first(where: { $0.axis == .x })?.bufferName

        let aspectRatio: CGFloat = try attributes.optionalValue(for: .aspectRatio) ?? 3.0
        let dots = attributes.optionalString(for: .style) ?? "line" == "dots"
        let partialUpdate = try attributes.optionalValue(for: .partialUpdate) ?? false
        let history: UInt = try attributes.optionalValue(for: .history) ?? 1
        let lineWidth: CGFloat = try attributes.optionalValue(for: .lineWidth) ?? 1.0
        let colorString: String? = attributes.optionalString(for: .color)

        let color = try colorString.map({ string -> UIColor in
            guard let color = UIColor(hexString: string) else {
                throw ElementHandlerError.unexpectedAttributeValue("color")
            }

            return color
        }) ?? kHighlightColor

        let logX = try attributes.optionalValue(for: .logX) ?? false
        let logY = try attributes.optionalValue(for: .logY) ?? false
        let xPrecision: UInt = try attributes.optionalValue(for: .xPrecision) ?? 3
        let yPrecision: UInt = try attributes.optionalValue(for: .yPrecision) ?? 3

        let scaleMinX: GraphViewDescriptor.ScaleMode = try attributes.optionalValue(for: .scaleMinX) ?? .auto
        let scaleMaxX: GraphViewDescriptor.ScaleMode = try attributes.optionalValue(for: .scaleMaxX) ?? .auto
        let scaleMinY: GraphViewDescriptor.ScaleMode = try attributes.optionalValue(for: .scaleMinY) ?? .auto
        let scaleMaxY: GraphViewDescriptor.ScaleMode = try attributes.optionalValue(for: .scaleMaxY) ?? .auto

        let minX: CGFloat = try attributes.optionalValue(for: .minX) ?? 0
        let maxX: CGFloat = try attributes.optionalValue(for: .maxX) ?? 0
        let minY: CGFloat = try attributes.optionalValue(for: .minY) ?? 0
        let maxY: CGFloat = try attributes.optionalValue(for: .maxY) ?? 0

        results.append(GraphViewElementDescriptor(label: label, xLabel: xLabel, yLabel: yLabel, logX: logX, logY: logY, xPrecision: xPrecision, yPrecision: yPrecision, minX: minX, maxX: maxX, minY: minY, maxY: maxY, scaleMinX: scaleMinX, scaleMaxX: scaleMaxX, scaleMinY: scaleMinY, scaleMaxY: scaleMaxY, xInputBufferName: xInputBufferName, yInputBufferName: yInputBufferName, aspectRatio: aspectRatio, partialUpdate: partialUpdate, drawDots: dots, history: history, lineWidth: lineWidth, color: color))
    }

    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}
