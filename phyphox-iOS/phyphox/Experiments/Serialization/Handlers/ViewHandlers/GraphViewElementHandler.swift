//
//  GraphViewElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

// This file contains element handlers for the `graph` view element (and its child elements).

private enum GraphAxis: String, CaseInsensitiveAttributeDecodable, CaseIterable {
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
        //A present but unparseable per-set colour is an error (color-invalid-value in
        //phyphox-docs); Android's message for the input tag differs from the attribute one
        let color: UIColor?
        if let colorString = attributes.optionalString(for: .color) {
            guard let parsedColor = mapColorString(colorString) else {
                throw ElementHandlerError.message("Could not parse color of input tag.")
            }
            color = parsedColor
        } else {
            color = nil
        }
        //An invalid style is an error rather than being silently ignored (enum-invalid-value
        //in phyphox-docs; Android throws "Unknown value for style of input tag." here)
        let style: GraphViewDescriptor.GraphStyle? = try attributes.optionalValue(for: .style)

        results.append(GraphInputDescriptor(axis: axis, color: color, lineWidth: lineWidth, style: style, bufferName: text))
    }
}

enum GraphPickAxis: String, CaseInsensitiveAttributeDecodable, CaseIterable {
    case x
    case xcal
    case y
    case ycal
    case z
    case zcal

    //Offset within a block of six slots (x, xcal, y, ycal, z, zcal). A repeated
    //axis starts the next block, matching the layout used by the Android app.
    var slotOffset: Int {
        switch self {
        case .x: return 0
        case .xcal: return 1
        case .y: return 2
        case .ycal: return 3
        case .z: return 4
        case .zcal: return 5
        }
    }
}

struct GraphPickOutput {
    let label: String
    let bufferName: String
}

private struct GraphOutputDescriptor {
    let axis: GraphPickAxis
    let label: String
    let bufferName: String
}

private final class GraphOutputElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [GraphOutputDescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case axis
        case label
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        guard !text.isEmpty else {
            throw ElementHandlerError.missingText
        }

        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let axis: GraphPickAxis = try attributes.value(for: .axis)
        let label = attributes.optionalString(for: .label) ?? ""

        results.append(GraphOutputDescriptor(axis: axis, label: label, bufferName: text))
    }


}

struct GraphViewElementDescriptor {
    let label: String
    let visibility: String
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
    let hideTimeMarkers: Bool
    
    let logX: Bool
    let logY: Bool
    let logZ: Bool

    let xPrecision: Int
    let yPrecision: Int
    let zPrecision: Int
    let suppressScientificNotation: Bool

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
    
    let followX: Bool
    
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
    let showColorScale: Bool
    let interpolateMapColors: Bool

    let pickLabel: String
    var pickOutputs: [GraphPickOutput?]
}

final class GraphViewElementHandler: ResultElementHandler, LookupElementHandler, ViewComponentElementHandler {
    var results = [ViewElementDescriptor]()

    var childHandlers: [String : ElementHandler]

    private let inputHandler = GraphInputElementHandler()
    private let outputHandler = GraphOutputElementHandler()

    init() {
        childHandlers = ["input": inputHandler, "output": outputHandler]
    }

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case label
        case visibility
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
        case hideTimeMarkers
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
        case suppressScientificNotation
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
        case followX
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
        case showColorScale
        case interpolateMapColors
        case pickLabel
    }
    
    func endElement(text: String, attributes: AttributeContainer) throws {
        //The numbered mapColor attributes are read via dynamic keys, so their count is unbounded
        let numberedAttributes = attributes.attributes(keyedBy: String.self)
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let label = attributes.optionalString(for: .label) ?? ""
        let visibility = attributes.optionalString(for: .visibility) ?? ""
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
        let hideTimeMarkers = try attributes.optionalValue(for: .hideTimeMarkers) ?? false

        let aspectRatio: CGFloat = try attributes.optionalValue(for: .aspectRatio) ?? 2.5
        //An invalid style is an error, only an absent attribute selects the default
        //(enum-invalid-value in phyphox-docs)
        let style: GraphViewDescriptor.GraphStyle = try attributes.optionalValue(for: .style) ?? .lines
        var partialUpdate = try attributes.optionalValue(for: .partialUpdate) ?? false
        let history: UInt = try attributes.optionalValue(for: .history) ?? 1
        let lineWidth: CGFloat = try attributes.optionalValue(for: .lineWidth) ?? 1.0
        let color = try attributes.optionalColor(for: .color)

        //The colour scale has as many stops as the file provides, numbered from 1 and ending at
        //the first ABSENT stop - without the former cap of nine (views-map-color-limit in
        //phyphox-docs). A stop that is present but unparseable is an error, not the end of the
        //scale (color-invalid-value in phyphox-docs).
        var colorMap: [UIColor] = []
        var mapColorIndex = 1
        while let mapColor = try numberedAttributes.optionalColor(for: "mapColor\(mapColorIndex)") {
            colorMap.append(mapColor)
            mapColorIndex += 1
        }
        let mapWidth: UInt = try attributes.optionalValue(for: .mapWidth) ?? 0
        let showColorScale: Bool = try attributes.optionalValue(for: .showColorScale) ?? true

        let interpolateMapColors: Bool = try attributes.optionalValue(for: .interpolateMapColors) ?? true
        

        let logX = try attributes.optionalValue(for: .logX) ?? false
        let logY = try attributes.optionalValue(for: .logY) ?? false
        let logZ = try attributes.optionalValue(for: .logZ) ?? false
        let xPrecision: Int = try attributes.optionalValue(for: .xPrecision) ?? -1
        let yPrecision: Int = try attributes.optionalValue(for: .yPrecision) ?? -1
        let zPrecision: Int = try attributes.optionalValue(for: .zPrecision) ?? -1
        let suppressScientificNotation = try attributes.optionalValue(for: .suppressScientificNotation) ?? false

        var scaleMinX: GraphViewDescriptor.ScaleMode = try attributes.optionalValue(for: .scaleMinX) ?? .auto
        var scaleMaxX: GraphViewDescriptor.ScaleMode = try attributes.optionalValue(for: .scaleMaxX) ?? .auto
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

        let followX: Bool = try attributes.optionalValue(for: .followX) ?? false
        if followX {
            scaleMinX = .fixed
            scaleMaxX = .fixed
            partialUpdate = true
        }
        
        let inputBuffers = inputHandler.results
        guard inputBuffers.count > 0 else {
            throw ElementHandlerError.missingElement("input")
        }
        
        //Dataset pairing follows the decided model (graph-multiset-omitted-x and
        //graph-multiset-input-order in phyphox-docs, amended 2026-08-20): every y input is one
        //dataset. With exactly as many x inputs as y inputs (z inputs do not count), they are
        //matched 1-on-1 in order of appearance regardless of interleaving. With fewer x than y
        //inputs, each y is plotted against the most recent preceding x input, or against its
        //element index if none preceded it. Any x input that no y input uses - trailing, or
        //shadowed by a later x before any y consumed it - is a load error; that can only arise
        //with unequal counts. Styling attributes on an x input apply to its matched dataset; a
        //shared x styles only the first dataset that uses it.
        let xInputs = inputBuffers.filter { $0.axis == .x }
        let yInputs = inputBuffers.filter { $0.axis == .y }
        guard !yInputs.isEmpty else {
            throw ElementHandlerError.missingChildElement("input[axis=y]")
        }

        var xForDataset: [GraphInputDescriptor?]
        var xStylesDataset: [Bool]
        if xInputs.count == yInputs.count {
            xForDataset = xInputs
            xStylesDataset = [Bool](repeating: true, count: yInputs.count)
        } else {
            xForDataset = []
            xStylesDataset = []
            var precedingX: GraphInputDescriptor? = nil
            var precedingXUsed = true
            for inputBuffer in inputBuffers {
                switch inputBuffer.axis {
                case .x:
                    guard precedingXUsed else {
                        throw ElementHandlerError.missingChildElement("input[axis=y]")
                    }
                    precedingX = inputBuffer
                    precedingXUsed = false
                case .y:
                    xForDataset.append(precedingX)
                    xStylesDataset.append(!precedingXUsed)
                    precedingXUsed = true
                case .z:
                    break
                }
            }
            guard precedingXUsed else {
                throw ElementHandlerError.missingChildElement("input[axis=y]")
            }
        }

        var xInputBufferNames: [String?] = []
        var yInputBufferNames: [String] = []
        var zInputBufferNames = [String?](repeating: nil, count: yInputs.count)
        var colors: [UIColor] = []
        var lineWidths: [CGFloat] = []
        var styles: [GraphViewDescriptor.GraphStyle] = []
        for (i, yInput) in yInputs.enumerated() {
            let autoColor: UIColor?
            switch i % 6 {
                case 0: autoColor = namedColors["orange"]
                case 1: autoColor = namedColors["green"]
                case 2: autoColor = namedColors["blue"]
                case 3: autoColor = namedColors["yellow"]
                case 4: autoColor = namedColors["magenta"]
                case 5: autoColor = namedColors["red"]
                default: autoColor = namedColors["orange"]
            }
            let xStyling = xStylesDataset[i] ? xForDataset[i] : nil
            xInputBufferNames.append(xForDataset[i]?.bufferName)
            yInputBufferNames.append(yInput.bufferName)
            colors.append(yInput.color ?? xStyling?.color ?? color ?? autoColor ?? kHighlightColor)
            lineWidths.append(yInput.lineWidth ?? xStyling?.lineWidth ?? lineWidth)
            styles.append(yInput.style ?? xStyling?.style ?? style)
        }

        //z inputs attach to the dataset of the most recent preceding y input, or to the first
        //dataset if none preceded
        var yCount = 0
        for inputBuffer in inputBuffers {
            switch inputBuffer.axis {
            case .x:
                break
            case .y:
                yCount += 1
            case .z:
                let datasetIndex = max(yCount - 1, 0)
                zInputBufferNames[datasetIndex] = inputBuffer.bufferName
                if let color = inputBuffer.color {
                    colors[datasetIndex] = color
                }
                if let lineWidth = inputBuffer.lineWidth {
                    lineWidths[datasetIndex] = lineWidth
                }
                if let style = inputBuffer.style {
                    styles[datasetIndex] = style
                }
            }
        }
        
        let pickLabel = attributes.optionalString(for: .pickLabel) ?? ""

        //Data picker outputs are kept in slots of six (x, xcal, y, ycal, z, zcal).
        //The n-th occurrence of an axis goes into block n, like on Android.
        var pickOutputs: [GraphPickOutput?] = []
        var axisOccurrences: [GraphPickAxis: Int] = [:]
        for output in outputHandler.results {
            let block = axisOccurrences[output.axis] ?? 0
            axisOccurrences[output.axis] = block + 1
            let slot = block * 6 + output.axis.slotOffset
            while pickOutputs.count <= slot {
                pickOutputs.append(nil)
            }
            pickOutputs[slot] = GraphPickOutput(label: output.label, bufferName: output.bufferName)
        }


        results.append(.graph(GraphViewElementDescriptor(label: label, visibility: visibility, xLabel: xLabel, yLabel: yLabel, zLabel: zLabel, xUnit: xUnit, yUnit: yUnit, zUnit: zUnit, yxUnit: yxUnit, timeOnX: timeOnX, timeOnY: timeOnY, systemTime: systemTime, linearTime: linearTime, hideTimeMarkers: hideTimeMarkers, logX: logX, logY: logY, logZ: logZ, xPrecision: xPrecision, yPrecision: yPrecision, zPrecision: zPrecision, suppressScientificNotation: suppressScientificNotation, minX: minX, maxX: maxX, minY: minY, maxY: maxY, minZ: minZ, maxZ: maxZ, scaleMinX: scaleMinX, scaleMaxX: scaleMaxX, scaleMinY: scaleMinY, scaleMaxY: scaleMaxY, scaleMinZ: scaleMinZ, scaleMaxZ: scaleMaxZ, followX: followX, mapWidth: mapWidth, colorMap: colorMap, xInputBufferNames: xInputBufferNames, yInputBufferNames: yInputBufferNames, zInputBufferNames: zInputBufferNames, aspectRatio: aspectRatio, partialUpdate: partialUpdate, history: history, lineWidth: lineWidths, color: colors, style: styles, showColorScale: showColorScale, interpolateMapColors: interpolateMapColors, pickLabel: pickLabel, pickOutputs: pickOutputs)))
    }

    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}
