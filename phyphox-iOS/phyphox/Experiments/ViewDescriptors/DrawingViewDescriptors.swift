//
//  DrawingViewDescriptors.swift
//  phyphox
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import Foundation

///geometry (file format 1.21, phyphox-docs views/drawing.md): a static shape. Nothing in it reads a data container; the
///label has no effect. The remote interface draws it from the "geometry" object (webinterface readme.md, "Drawing elements").
struct GeometryViewDescriptor: ViewDescriptor {
    let label = ""
    let translation: ExperimentTranslationCollection? = nil
    let visibilityBuffer: DataBuffer?
    let attributes: GeometryViewElementDescriptor

    func generateViewHTMLWithID(_ id: Int) -> String {
        return "<div class=\"geometryElement\" id=\"element\(id)\"></div>"
    }

    ///All keys always present, a colour as "#rrggbb"/"#rrggbbaa" or null (the readme's table)
    func webGeometryConfig() -> String {
        let a = attributes
        let config: WebJSON.Object = [
            ("shape", a.shape.rawValue),
            ("aspectRatio", a.aspectRatio),
            ("color", a.color.map { "#" + $0.webHexString }),
            ("lineColor", a.lineColor.map { "#" + $0.webHexString }),
            ("lineWidth", a.lineWidth),
            ("left", a.left),
            ("top", a.top),
            ("right", a.right),
            ("bottom", a.bottom),
            ("cornerRadius", a.cornerRadius),
            ("centerX", a.centerX),
            ("centerY", a.centerY),
            ("radius", a.radius),
            ("innerRadius", a.innerRadius),
            ("startAngle", a.startAngle),
            ("sweepAngle", a.sweepAngle),
            ("startX", a.startX),
            ("startY", a.startY),
            ("endX", a.endX),
            ("endY", a.endY)
        ]
        return WebJSON.encode(config)
    }
}

///scale (file format 1.21, phyphox-docs views/drawing.md): the axis of a gauge. The geometry comes from the attributes,
///the range from min/max or the containers an input child binds them to; the label is the axis label. The unit is a
///logical unit like a value's, so a reference takes part in the unit conversion.
struct ScaleViewDescriptor: ViewDescriptor {
    let label: String
    let translation: ExperimentTranslationCollection?
    let visibilityBuffer: DataBuffer?
    let unit: Unit
    let minBuffer: DataBuffer?
    let maxBuffer: DataBuffer?
    let attributes: ScaleViewElementDescriptor

    var isConvertible: Bool {
        return unit.isConvertible
    }

    ///The bound containers, each once, in min/max order - what the remote interface polls
    var webDataInputs: [DataBuffer] {
        var inputs: [DataBuffer] = []
        for buffer in [minBuffer, maxBuffer] {
            if let buffer = buffer, !inputs.contains(where: { $0 === buffer }) {
                inputs.append(buffer)
            }
        }
        return inputs
    }

    func generateViewHTMLWithID(_ id: Int) -> String {
        return "<div class=\"scaleElement\" id=\"element\(id)\"></div>"
    }

    ///All keys always present (the readme's table); the unit as the {"id", "text"} object of a value element
    func webScaleConfig() -> String {
        let a = attributes
        let config: WebJSON.Object = [
            ("shape", a.shape.rawValue),
            ("aspectRatio", a.aspectRatio),
            ("min", a.min),
            ("max", a.max),
            ("minInput", minBuffer?.name),
            ("maxInput", maxBuffer?.name),
            ("unit", unit.webJSON),
            ("color", a.color.map { "#" + $0.webHexString }),
            ("size", a.size),
            ("lineWidth", a.lineWidth),
            ("ticStep", a.ticStep),
            ("ticLength", a.ticLength),
            ("minorTics", a.minorTics),
            ("minorTicLength", a.minorTicLength),
            ("valueEvery", a.valueEvery),
            ("valueDistance", a.valueDistance),
            ("precision", a.precision),
            ("valueOrientation", a.valueOrientation.rawValue),
            ("labelPositionX", a.labelPositionX),
            ("labelPositionY", a.labelPositionY),
            ("startX", a.startX),
            ("startY", a.startY),
            ("endX", a.endX),
            ("endY", a.endY),
            ("centerX", a.centerX),
            ("centerY", a.centerY),
            ("radius", a.radius),
            ("startAngle", a.startAngle),
            ("sweepAngle", a.sweepAngle)
        ]
        return WebJSON.encode(config)
    }
}
