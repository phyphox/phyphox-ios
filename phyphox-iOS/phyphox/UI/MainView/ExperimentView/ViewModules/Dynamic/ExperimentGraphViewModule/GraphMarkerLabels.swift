//
//  GraphMarkerLabels.swift
//  phyphox
//
//  Created by Sebastian Staacks on 07.09.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import Foundation

//Text of the marker labels (point, difference with slope, linear fit), shared by GraphMarkerSystem and the deprecated graph view
struct GraphMarkerLabels {
    let descriptor: GraphViewDescriptor
    let logX, logY, logZ: Bool
    let hasZData: Bool

    static func makeFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.usesSignificantDigits = true
        formatter.minimumSignificantDigits = 4
        formatter.maximumSignificantDigits = 8
        return formatter
    }

    func singlePoint(x: GLfloat, y: GLfloat, z: GLfloat, formatter: NumberFormatter) -> String {
        var labelText = localize("graph_point_label")
        labelText += "\n    " + format(convert(x, isLogarithmic: logX), formatter) + unit(descriptor.localizedXUnit)
        labelText += "\n    " + format(convert(y, isLogarithmic: logY), formatter) + unit(descriptor.localizedYUnit)
        if hasZData {
            labelText += "\n    " + format(convert(z, isLogarithmic: logZ), formatter) + unit(descriptor.localizedZUnit)
        }
        return labelText
    }

    func difference(x1: GLfloat, x2: GLfloat, y1: GLfloat, y2: GLfloat, z1: GLfloat, z2: GLfloat, formatter: NumberFormatter) -> String {
        var labelText = localize("graph_difference_label")
        let convertedX1 = convert(x1, isLogarithmic: logX)
        let convertedX2 = convert(x2, isLogarithmic: logX)
        labelText += "\n    " + format(abs(convertedX1 - convertedX2), formatter) + unit(descriptor.localizedXUnit)
        let convertedY1 = convert(y1, isLogarithmic: logY)
        let convertedY2 = convert(y2, isLogarithmic: logY)
        labelText += "\n    " + format(abs(convertedY1 - convertedY2), formatter) + unit(descriptor.localizedYUnit)
        if hasZData {
            let dz = abs(convert(z1, isLogarithmic: logZ) - convert(z2, isLogarithmic: logZ))
            labelText += "\n    " + format(dz, formatter) + unit(descriptor.localizedZUnit)
        }
        labelText += "\n" + localize("graph_slope_label")
        let slope = (convertedY1 - convertedY2) / (convertedX1 - convertedX2)
        labelText += "\n    " + format(slope, formatter) + " " + descriptor.localizedYXUnit
        return labelText
    }

    func linearFit(slope: GLfloat, intercept: GLfloat, formatter: NumberFormatter) -> String {
        var labelText = localize("graph_fit_label")
        labelText += "\na = " + format(slope, formatter) + " " + descriptor.localizedYXUnit
        labelText += "\nb = " + format(intercept, formatter) + unit(descriptor.localizedYUnit)
        return labelText
    }

    private func convert(_ value: GLfloat, isLogarithmic: Bool) -> GLfloat {
        return isLogarithmic ? exp(value) : value
    }

    private func format(_ value: GLfloat, _ formatter: NumberFormatter) -> String {
        return formatter.string(from: value as NSNumber) ?? "N/A"
    }

    private func unit(_ unit: String) -> String {
        return unit.isEmpty ? "" : " " + unit
    }
}
