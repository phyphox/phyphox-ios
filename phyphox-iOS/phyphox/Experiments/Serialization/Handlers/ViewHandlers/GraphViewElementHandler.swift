//
//  GraphViewElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

// This file contains element handlers for the `graph` view element (and its child elements).

private enum GraphAxis: String, LosslessStringConvertible {
    case x
    case y
}

private struct GraphInputDescriptor {
    let axis: GraphAxis
    let color: UIColor?
    let lineWidth: CGFloat?
    let dots: Bool?
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
        case color
        case lineWidth
        case style
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        guard !text.isEmpty else {
            throw ElementHandlerError.missingText
        }

        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let axis: GraphAxis = try attributes.value(for: .axis)
        let lineWidth: CGFloat? = try attributes.optionalValue(for: .lineWidth)
        let color: UIColor? = mapColorString(attributes.optionalString(for: .color))
        let dots: Bool? = attributes.optionalString(for: .style) ?? "line" == "dots"

        results.append(GraphInputDescriptor(axis: axis, color: color, lineWidth: lineWidth, dots: dots, bufferName: text))
    }
}

struct GraphViewElementDescriptor {
    let label: String
    
    let xLabel: String
    let yLabel: String
    let xUnit: String?
    let yUnit: String?

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

    var xInputBufferNames: [String?]
    var yInputBufferNames: [String]

    let aspectRatio: CGFloat
    let partialUpdate: Bool
    let drawDots: [Bool]
    let history: UInt

    let lineWidth: [CGFloat]
    let color: [UIColor]
}

final class GraphViewElementHandler: ResultElementHandler, LookupElementHandler, ViewComponentElementHandler {
    var results = [ViewElementDescriptor]()

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
        case unitX
        case unitY
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
        let xUnit = attributes.optionalString(for: .unitX)
        let yUnit = attributes.optionalString(for: .unitY)

        let aspectRatio: CGFloat = try attributes.optionalValue(for: .aspectRatio) ?? 2.5
        let dots = attributes.optionalString(for: .style) ?? "line" == "dots"
        let partialUpdate = try attributes.optionalValue(for: .partialUpdate) ?? false
        let history: UInt = try attributes.optionalValue(for: .history) ?? 1
        let lineWidth: CGFloat = try attributes.optionalValue(for: .lineWidth) ?? 1.0
        let color = mapColorString(attributes.optionalString(for: .color))

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

        let inputBuffers = inputHandler.results
        guard inputBuffers.count > 0 else {
            throw ElementHandlerError.missingElement("input")
        }
        
        var xInputBufferNames: [String?] = []
        var yInputBufferNames: [String] = []
        var colors: [UIColor] = []
        var lineWidths: [CGFloat] = []
        var dotsList: [Bool] = []
        var inputCount = -1
        for inputBuffer in inputBuffers {
            if inputCount < 0 || inputBuffer.axis == .x || (inputBuffer.axis == .y && yInputBufferNames[inputCount] != "") {
                if (inputCount >= 0 && yInputBufferNames[inputCount] == "") {
                    throw ElementHandlerError.missingChildElement("input[axis=y]")
                }
                inputCount += 1
                let autoColor: UIColor?
                switch inputCount % 6 {
                    case 0: autoColor = namedColors["orange"]
                    case 1: autoColor = namedColors["green"]
                    case 2: autoColor = namedColors["blue"]
                    case 3: autoColor = namedColors["yellow"]
                    case 4: autoColor = namedColors["magenta"]
                    case 5: autoColor = namedColors["red"]
                    default: autoColor = namedColors["orange"]
                }
                colors.append(color ?? autoColor ?? kHighlightColor)
                lineWidths.append(lineWidth)
                dotsList.append(dots)
                if inputCount > 0 {
                    xInputBufferNames.append(xInputBufferNames[inputCount-1])
                } else {
                    xInputBufferNames.append(nil)
                }
                yInputBufferNames.append("")
            }
            switch inputBuffer.axis {
                case .x: xInputBufferNames[inputCount] = inputBuffer.bufferName
                case .y: yInputBufferNames[inputCount] = inputBuffer.bufferName
                default: yInputBufferNames[inputCount] = inputBuffer.bufferName
            }
            if let color = inputBuffer.color {
                colors[inputCount] = color
            }
            if let lineWidth = inputBuffer.lineWidth {
                lineWidths[inputCount] = lineWidth
            }
            if let dots = inputBuffer.dots {
                dotsList[inputCount] = dots
            }
        }
        
        results.append(.graph(GraphViewElementDescriptor(label: label, xLabel: xLabel, yLabel: yLabel, xUnit: xUnit, yUnit: yUnit, logX: logX, logY: logY, xPrecision: xPrecision, yPrecision: yPrecision, minX: minX, maxX: maxX, minY: minY, maxY: maxY, scaleMinX: scaleMinX, scaleMaxX: scaleMaxX, scaleMinY: scaleMinY, scaleMaxY: scaleMaxY, xInputBufferNames: xInputBufferNames, yInputBufferNames: yInputBufferNames, aspectRatio: aspectRatio, partialUpdate: partialUpdate, drawDots: dotsList, history: history, lineWidth: lineWidths, color: colors)))
    }

    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}
