//
//  DrawingViewElementHandlers.swift
//  phyphox
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import Foundation

// Element handlers for the drawing elements of file format 1.21 (phyphox-docs docs/file-format/views/drawing.md):
// geometry, a static shape, and scale, the axis of a gauge. Both are accepted wherever an image is (a view, the layout
// groups, a stack, a transform - the dispatch is ViewElementContainerHandler). Positions are fractions of the element's
// box, lengths fractions of its width, angles radians clockwise from twelve o'clock; the attributes are kept as read.

enum GeometryShape: String, CaseInsensitiveAttributeDecodable, CaseIterable {
    case rectangle, circle, line, arc
}

struct GeometryViewElementDescriptor {
    let visibility: String
    let shape: GeometryShape
    let aspectRatio: Double
    let color: UIColor?      //fill of an area shape, or the colour of a line without lineColor
    let lineColor: UIColor?  //outline of an area shape, or the colour of a line
    let lineWidth: Double    //as a fraction of the width
    //rectangle
    let left: Double
    let top: Double
    let right: Double
    let bottom: Double
    let cornerRadius: Double
    //circle, arc
    let centerX: Double
    let centerY: Double
    let radius: Double
    let innerRadius: Double
    let startAngle: Double
    let sweepAngle: Double
    //line
    let startX: Double
    let startY: Double
    let endX: Double
    let endY: Double
}

///geometry: label has no effect, so it is not read
final class GeometryViewElementHandler: ResultElementHandler, ChildlessElementHandler, ViewComponentElementHandler {
    var results = [ViewElementDescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case visibility
        case shape
        case aspectRatio
        case color
        case lineColor
        case lineWidth
        case left
        case top
        case right
        case bottom
        case cornerRadius
        case centerX
        case centerY
        case radius
        case innerRadius
        case startAngle
        case sweepAngle
        case startX
        case startY
        case endX
        case endY
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let visibility = attributes.optionalString(for: .visibility) ?? ""
        //An unknown shape is an error like any invalid enumerated value (enum-invalid-value), matched case-insensitively
        let shape: GeometryShape = try attributes.optionalValue(for: .shape) ?? .rectangle

        results.append(.geometry(GeometryViewElementDescriptor(
            visibility: visibility,
            shape: shape,
            aspectRatio: try attributes.optionalValue(for: .aspectRatio) ?? 1.0,
            color: try attributes.optionalColor(for: .color),
            lineColor: try attributes.optionalColor(for: .lineColor),
            lineWidth: try attributes.optionalValue(for: .lineWidth) ?? 0.01,
            left: try attributes.optionalValue(for: .left) ?? 0.0,
            top: try attributes.optionalValue(for: .top) ?? 0.0,
            right: try attributes.optionalValue(for: .right) ?? 1.0,
            bottom: try attributes.optionalValue(for: .bottom) ?? 1.0,
            cornerRadius: try attributes.optionalValue(for: .cornerRadius) ?? 0.0,
            centerX: try attributes.optionalValue(for: .centerX) ?? 0.5,
            centerY: try attributes.optionalValue(for: .centerY) ?? 0.5,
            radius: try attributes.optionalValue(for: .radius) ?? 0.5,
            innerRadius: try attributes.optionalValue(for: .innerRadius) ?? 0.0,
            startAngle: try attributes.optionalValue(for: .startAngle) ?? 0.0,
            sweepAngle: try attributes.optionalValue(for: .sweepAngle) ?? 6.2832,
            startX: try attributes.optionalValue(for: .startX) ?? 0.0,
            startY: try attributes.optionalValue(for: .startY) ?? 0.5,
            endX: try attributes.optionalValue(for: .endX) ?? 1.0,
            endY: try attributes.optionalValue(for: .endY) ?? 0.5)))
    }

    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}

enum ScaleShape: String, CaseInsensitiveAttributeDecodable, CaseIterable {
    case linear, circular
}

enum ScaleValueOrientation: String, CaseInsensitiveAttributeDecodable, CaseIterable {
    case upright, tangential, radial
}

///Which end of the range an input child of a scale binds
enum ScaleRangeEnd: String, CaseInsensitiveAttributeDecodable, CaseIterable {
    case min, max
}

struct ScaleViewElementDescriptor {
    let label: String
    let visibility: String
    let shape: ScaleShape
    let aspectRatio: Double
    let min: Double              //in the experiment's unit
    let max: Double
    let unit: String?            //resolved to a logical unit where the file version is known (PhyphoxElementHandler)
    let color: UIColor?          //baseline, tics and text; nil is the text colour of the theme
    let size: Double             //text size relative to the default, like the value element's
    let lineWidth: Double        //baseline and tics, as a fraction of the width; 0 draws no baseline
    let ticStep: Double          //0: automatic, like a graph axis
    let ticLength: Double        //signed: positive is outward on a circular scale, right of the direction of travel on a linear one
    let minorTics: Int
    let minorTicLength: Double
    let valueEvery: Int          //the value at every n-th major tic counted from min; 0: no values
    let valueDistance: Double
    let precision: Int?          //decimals of the values; nil: as many as the step needs
    let valueOrientation: ScaleValueOrientation
    let labelPositionX: Double
    let labelPositionY: Double
    //linear
    let startX: Double
    let startY: Double
    let endX: Double
    let endY: Double
    //circular
    let centerX: Double
    let centerY: Double
    let radius: Double
    let startAngle: Double
    let sweepAngle: Double
    //The data containers bound to min and max by the input children, or nil
    let minInputBufferName: String?
    let maxInputBufferName: String?
}

///The input children of a scale: as="min" or as="max" and the name of a data container
private final class ScaleInputElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [(end: ScaleRangeEnd, bufferName: String)]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case `as`
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        guard !text.isEmpty else {
            throw ElementHandlerError.missingText
        }

        let attributes = attributes.attributes(keyedBy: Attribute.self)
        let end: ScaleRangeEnd = try attributes.value(for: .as)

        results.append((end, text))
    }
}

///scale: label is the axis label (translatable), input children bind the range to data containers
final class ScaleViewElementHandler: ResultElementHandler, LookupElementHandler, ViewComponentElementHandler {
    var results = [ViewElementDescriptor]()

    var childHandlers: [String: ElementHandler]

    private let inputHandler = ScaleInputElementHandler()

    init() {
        childHandlers = ["input": inputHandler]
    }

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case label
        case visibility
        case shape
        case aspectRatio
        case min
        case max
        case unit
        case color
        case size
        case lineWidth
        case ticStep
        case ticLength
        case minorTics
        case minorTicLength
        case valueEvery
        case valueDistance
        case precision
        case valueOrientation
        case labelPositionX
        case labelPositionY
        case startX
        case startY
        case endX
        case endY
        case centerX
        case centerY
        case radius
        case startAngle
        case sweepAngle
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let label = attributes.optionalString(for: .label) ?? ""
        let visibility = attributes.optionalString(for: .visibility) ?? ""
        //Enumerated values are matched case-insensitively; an unknown one is an error (enum-invalid-value)
        let shape: ScaleShape = try attributes.optionalValue(for: .shape) ?? .linear
        let valueOrientation: ScaleValueOrientation = try attributes.optionalValue(for: .valueOrientation) ?? .upright

        //A later input for the same end wins, like the inputs of a transform
        var minInputBufferName: String? = nil
        var maxInputBufferName: String? = nil
        for input in inputHandler.results {
            switch input.end {
            case .min: minInputBufferName = input.bufferName
            case .max: maxInputBufferName = input.bufferName
            }
        }

        results.append(.scale(ScaleViewElementDescriptor(
            label: label,
            visibility: visibility,
            shape: shape,
            aspectRatio: try attributes.optionalValue(for: .aspectRatio) ?? 1.0,
            min: try attributes.optionalValue(for: .min) ?? 0.0,
            max: try attributes.optionalValue(for: .max) ?? 1.0,
            unit: attributes.optionalString(for: .unit),
            color: try attributes.optionalColor(for: .color),
            size: try attributes.optionalValue(for: .size) ?? 1.0,
            lineWidth: try attributes.optionalValue(for: .lineWidth) ?? 0.005,
            ticStep: try attributes.optionalValue(for: .ticStep) ?? 0.0,
            ticLength: try attributes.optionalValue(for: .ticLength) ?? 0.03,
            minorTics: try attributes.optionalValue(for: .minorTics) ?? 0,
            minorTicLength: try attributes.optionalValue(for: .minorTicLength) ?? 0.015,
            valueEvery: try attributes.optionalValue(for: .valueEvery) ?? 1,
            valueDistance: try attributes.optionalValue(for: .valueDistance) ?? 0.08,
            precision: try attributes.optionalValue(for: .precision),
            valueOrientation: valueOrientation,
            labelPositionX: try attributes.optionalValue(for: .labelPositionX) ?? 0.5,
            labelPositionY: try attributes.optionalValue(for: .labelPositionY) ?? 0.5,
            startX: try attributes.optionalValue(for: .startX) ?? 0.1,
            startY: try attributes.optionalValue(for: .startY) ?? 0.5,
            endX: try attributes.optionalValue(for: .endX) ?? 0.9,
            endY: try attributes.optionalValue(for: .endY) ?? 0.5,
            centerX: try attributes.optionalValue(for: .centerX) ?? 0.5,
            centerY: try attributes.optionalValue(for: .centerY) ?? 0.5,
            radius: try attributes.optionalValue(for: .radius) ?? 0.4,
            startAngle: try attributes.optionalValue(for: .startAngle) ?? -2.3562,
            sweepAngle: try attributes.optionalValue(for: .sweepAngle) ?? 4.7124,
            minInputBufferName: minInputBufferName,
            maxInputBufferName: maxInputBufferName)))
    }

    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}
