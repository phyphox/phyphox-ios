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
    case z
}

private struct GraphInputDescriptor {
    let axis: GraphAxis
    let color: UIColor?
    let lineWidth: CGFloat?
    let style: GraphViewDescriptor.GraphStyle?
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
        let styleString = attributes.optionalString(for: .style)
        let style = styleString != nil ? GraphViewDescriptor.GraphStyle(styleString!) : nil

        results.append(GraphInputDescriptor(axis: axis, color: color, lineWidth: lineWidth, style: style, bufferName: text))
    }
}

struct GraphViewElementDescriptor {
    let label: String
    
    let xLabel: String
    let yLabel: String
    let zLabel: String?
    let xUnit: String?
    let yUnit: String?
    let zUnit: String?
    let yxUnit: String?

    let timeOnX: Bool
    let timeOnY: Bool
    let systemTime: Bool
    let linearTime: Bool
    
    let logX: Bool
    let logY: Bool
    let logZ: Bool

    let xPrecision: UInt
    let yPrecision: UInt
    let zPrecision: UInt

    let minX: CGFloat
    let maxX: CGFloat
    let minY: CGFloat
    let maxY: CGFloat
    let minZ: CGFloat
    let maxZ: CGFloat

    let scaleMinX: GraphViewDescriptor.ScaleMode
    let scaleMaxX: GraphViewDescriptor.ScaleMode
    let scaleMinY: GraphViewDescriptor.ScaleMode
    let scaleMaxY: GraphViewDescriptor.ScaleMode
    let scaleMinZ: GraphViewDescriptor.ScaleMode
    let scaleMaxZ: GraphViewDescriptor.ScaleMode
    
    let mapWidth: UInt
    let colorMap: [UIColor]

    var xInputBufferNames: [String?]
    var yInputBufferNames: [String]
    var zInputBufferNames: [String?]

    let aspectRatio: CGFloat
    let partialUpdate: Bool
    let history: UInt

    let lineWidth: [CGFloat]
    let color: [UIColor]
    let style: [GraphViewDescriptor.GraphStyle]
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
        case labelZ
        case unitX
        case unitY
        case unitZ
        case unitYperX
        case timeOnX
        case timeOnY
        case systemTime
        case linearTime
        case aspectRatio
        case style
        case partialUpdate
        case history
        case lineWidth
        case color
        case logX
        case logY
        case logZ
        case xPrecision
        case yPrecision
        case zPrecision
        case scaleMinX
        case scaleMaxX
        case scaleMinY
        case scaleMaxY
        case scaleMinZ
        case scaleMaxZ
        case minX
        case maxX
        case minY
        case maxY
        case minZ
        case maxZ
        case mapWidth
        case mapColor1
        case mapColor2
        case mapColor3
        case mapColor4
        case mapColor5
        case mapColor6
        case mapColor7
        case mapColor8
        case mapColor9
    }
    
    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let label = attributes.optionalString(for: .label) ?? ""
        let xLabel = attributes.optionalString(for: .labelX) ?? ""
        let yLabel = attributes.optionalString(for: .labelY) ?? ""
        let zLabel = attributes.optionalString(for: .labelZ)
        let xUnit = attributes.optionalString(for: .unitX)
        let yUnit = attributes.optionalString(for: .unitY)
        let zUnit = attributes.optionalString(for: .unitZ)
        let yxUnit = attributes.optionalString(for: .unitYperX)
        
        let timeOnX = try attributes.optionalValue(for: .timeOnX) ?? false
        let timeOnY = try attributes.optionalValue(for: .timeOnY) ?? false
        let systemTime = try attributes.optionalValue(for: .systemTime) ?? false
        let linearTime = try attributes.optionalValue(for: .linearTime) ?? false

        let aspectRatio: CGFloat = try attributes.optionalValue(for: .aspectRatio) ?? 2.5
        let style = GraphViewDescriptor.GraphStyle(attributes.optionalString(for: .style) ?? "") ?? .lines
        let partialUpdate = try attributes.optionalValue(for: .partialUpdate) ?? false
        let history: UInt = try attributes.optionalValue(for: .history) ?? 1
        let lineWidth: CGFloat = try attributes.optionalValue(for: .lineWidth) ?? 1.0
        let color = mapColorString(attributes.optionalString(for: .color))
        
        var colorMap: [UIColor] = []
        let mapColorCases = [Attribute.mapColor1, Attribute.mapColor2, Attribute.mapColor3, Attribute.mapColor4, Attribute.mapColor5, Attribute.mapColor6, Attribute.mapColor7, Attribute.mapColor8, Attribute.mapColor9]
        for attribute in mapColorCases {
            if let mapColor = mapColorString(attributes.optionalString(for: attribute)) {
                colorMap.append(mapColor)
            } else {
                break
            }
        }
        let mapWidth: UInt = try attributes.optionalValue(for: .mapWidth) ?? 0
        

        let logX = try attributes.optionalValue(for: .logX) ?? false
        let logY = try attributes.optionalValue(for: .logY) ?? false
        let logZ = try attributes.optionalValue(for: .logZ) ?? false
        let xPrecision: UInt = try attributes.optionalValue(for: .xPrecision) ?? 3
        let yPrecision: UInt = try attributes.optionalValue(for: .yPrecision) ?? 3
        let zPrecision: UInt = try attributes.optionalValue(for: .zPrecision) ?? 3

        let scaleMinX: GraphViewDescriptor.ScaleMode = try attributes.optionalValue(for: .scaleMinX) ?? .auto
        let scaleMaxX: GraphViewDescriptor.ScaleMode = try attributes.optionalValue(for: .scaleMaxX) ?? .auto
        let scaleMinY: GraphViewDescriptor.ScaleMode = try attributes.optionalValue(for: .scaleMinY) ?? .auto
        let scaleMaxY: GraphViewDescriptor.ScaleMode = try attributes.optionalValue(for: .scaleMaxY) ?? .auto
        let scaleMinZ: GraphViewDescriptor.ScaleMode = try attributes.optionalValue(for: .scaleMinZ) ?? .auto
        let scaleMaxZ: GraphViewDescriptor.ScaleMode = try attributes.optionalValue(for: .scaleMaxZ) ?? .auto

        let minX: CGFloat = try attributes.optionalValue(for: .minX) ?? 0
        let maxX: CGFloat = try attributes.optionalValue(for: .maxX) ?? 0
        let minY: CGFloat = try attributes.optionalValue(for: .minY) ?? 0
        let maxY: CGFloat = try attributes.optionalValue(for: .maxY) ?? 0
        let minZ: CGFloat = try attributes.optionalValue(for: .minZ) ?? 0
        let maxZ: CGFloat = try attributes.optionalValue(for: .maxZ) ?? 0

        let inputBuffers = inputHandler.results
        guard inputBuffers.count > 0 else {
            throw ElementHandlerError.missingElement("input")
        }
        
        var xInputBufferNames: [String?] = []
        var yInputBufferNames: [String] = []
        var zInputBufferNames: [String?] = []
        var colors: [UIColor] = []
        var lineWidths: [CGFloat] = []
        var styles: [GraphViewDescriptor.GraphStyle] = []
        var inputCount = -1
        for inputBuffer in inputBuffers {
            if inputCount < 0 || (inputBuffer.axis == .x && inputBuffers.count > 2 ) || (inputBuffer.axis == .y && yInputBufferNames[inputCount] != "") {
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
                styles.append(style)
                if inputCount > 0 {
                    xInputBufferNames.append(xInputBufferNames[inputCount-1])
                } else {
                    xInputBufferNames.append(nil)
                }
                yInputBufferNames.append("")
                zInputBufferNames.append(nil)
            }
            switch inputBuffer.axis {
                case .x: xInputBufferNames[inputCount] = inputBuffer.bufferName
                case .y: yInputBufferNames[inputCount] = inputBuffer.bufferName
                case .z: zInputBufferNames[inputCount] = inputBuffer.bufferName
            }
            if let color = inputBuffer.color {
                colors[inputCount] = color
            }
            if let lineWidth = inputBuffer.lineWidth {
                lineWidths[inputCount] = lineWidth
            }
            if let style = inputBuffer.style {
                styles[inputCount] = style
            }
        }
        
        results.append(.graph(GraphViewElementDescriptor(label: label, xLabel: xLabel, yLabel: yLabel, zLabel: zLabel, xUnit: xUnit, yUnit: yUnit, zUnit: zUnit, yxUnit: yxUnit, timeOnX: timeOnX, timeOnY: timeOnY, systemTime: systemTime, linearTime: linearTime, logX: logX, logY: logY, logZ: logZ, xPrecision: xPrecision, yPrecision: yPrecision, zPrecision: zPrecision, minX: minX, maxX: maxX, minY: minY, maxY: maxY, minZ: minZ, maxZ: maxZ, scaleMinX: scaleMinX, scaleMaxX: scaleMaxX, scaleMinY: scaleMinY, scaleMaxY: scaleMaxY, scaleMinZ: scaleMinZ, scaleMaxZ: scaleMaxZ, mapWidth: mapWidth, colorMap: colorMap, xInputBufferNames: xInputBufferNames, yInputBufferNames: yInputBufferNames, zInputBufferNames: zInputBufferNames, aspectRatio: aspectRatio, partialUpdate: partialUpdate, history: history, lineWidth: lineWidths, color: colors, style: styles)))
    }

    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}
