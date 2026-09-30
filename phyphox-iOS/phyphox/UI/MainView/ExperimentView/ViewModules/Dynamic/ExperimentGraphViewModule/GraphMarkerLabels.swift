//
//  GraphMarkerLabels.swift
//  phyphox
//
//  Created by Sebastian Staacks on 07.09.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import Foundation

//The units a graph shows per axis (x, y, z): the conversion from the experiment's unit, nil while that unit is shown,
//and the symbol drawn in the axis title and the read-outs (docs/file-format/units.md)
struct GraphDisplayUnits {
    var conversions: [UnitConversion?] = [nil, nil, nil]
    var symbols: [String]

    init(descriptor: GraphViewDescriptor) {
        symbols = [descriptor.localizedXUnit, descriptor.localizedYUnit, descriptor.localizedZUnit]
    }

    //A position (value, tick, picked point): scale and offset
    func toDisplay(_ axis: Int, _ v: Double) -> Double {
        return conversions[axis]?.toDisplay(v) ?? v
    }

    //A difference (Δ read-out, slope): the scale alone
    func scale(_ axis: Int) -> Double {
        return conversions[axis]?.scale ?? 1.0
    }

    var anyConverted: Bool {
        return conversions.contains { $0 != nil }
    }

    //The unit of a slope read-out: unitYperX while both axes show their experiment units, else composed from the
    //display symbols (units.md, "Slopes")
    func slopeUnit(descriptor: GraphViewDescriptor) -> String {
        if !anyConverted {
            return descriptor.localizedYXUnit
        }
        let uy = symbols[1]
        let ux = symbols[0]
        if ux.isEmpty {
            return uy
        }
        return (uy.isEmpty ? "1" : uy) + " / " + ux
    }
}

//Text of the marker labels (point, difference with slope, linear fit) in the units the graph shows
struct GraphMarkerLabels {
    let descriptor: GraphViewDescriptor
    let logX, logY, logZ: Bool
    let hasZData: Bool
    let displayUnits: GraphDisplayUnits

    static func makeFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.usesSignificantDigits = true
        formatter.minimumSignificantDigits = 4
        formatter.maximumSignificantDigits = 8
        return formatter
    }

    //The values arrive as the GL points' floats; the conversion and the formatting run in double precision
    func singlePoint(x: GLfloat, y: GLfloat, z: GLfloat, formatter: NumberFormatter) -> String {
        var labelText = localize("graph_point_label")
        labelText += "\n    " + format(displayUnits.toDisplay(0, convert(x, isLogarithmic: logX)), formatter) + unit(displayUnits.symbols[0])
        labelText += "\n    " + format(displayUnits.toDisplay(1, convert(y, isLogarithmic: logY)), formatter) + unit(displayUnits.symbols[1])
        if hasZData {
            labelText += "\n    " + format(displayUnits.toDisplay(2, convert(z, isLogarithmic: logZ)), formatter) + unit(displayUnits.symbols[2])
        }
        return labelText
    }

    func difference(x1: GLfloat, x2: GLfloat, y1: GLfloat, y2: GLfloat, z1: GLfloat, z2: GLfloat, formatter: NumberFormatter) -> String {
        //Differences use the scale alone, the slope the ratio of the two scales (units.md, "Temperature", "Slopes")
        var labelText = localize("graph_difference_label")
        let convertedX1 = convert(x1, isLogarithmic: logX)
        let convertedX2 = convert(x2, isLogarithmic: logX)
        labelText += "\n    " + format(abs(convertedX1 - convertedX2) * displayUnits.scale(0), formatter) + unit(displayUnits.symbols[0])
        let convertedY1 = convert(y1, isLogarithmic: logY)
        let convertedY2 = convert(y2, isLogarithmic: logY)
        labelText += "\n    " + format(abs(convertedY1 - convertedY2) * displayUnits.scale(1), formatter) + unit(displayUnits.symbols[1])
        if hasZData {
            let dz = abs(convert(z1, isLogarithmic: logZ) - convert(z2, isLogarithmic: logZ))
            labelText += "\n    " + format(dz * displayUnits.scale(2), formatter) + unit(displayUnits.symbols[2])
        }
        labelText += "\n" + localize("graph_slope_label")
        let slope = (convertedY1 - convertedY2) / (convertedX1 - convertedX2) * displayUnits.scale(1) / displayUnits.scale(0)
        labelText += "\n    " + format(slope, formatter) + " " + displayUnits.slopeUnit(descriptor: descriptor)
        return labelText
    }

    func linearFit(slope: GLfloat, intercept: GLfloat, formatter: NumberFormatter) -> String {
        //The fit is done on the data; the read-out shows it in the display units (slope by the scale ratio, b as a position)
        var labelText = localize("graph_fit_label")
        labelText += "\na = " + format(Double(slope) * displayUnits.scale(1) / displayUnits.scale(0), formatter) + " " + displayUnits.slopeUnit(descriptor: descriptor)
        labelText += "\nb = " + format(displayUnits.toDisplay(1, Double(intercept)), formatter) + unit(displayUnits.symbols[1])
        return labelText
    }

    private func convert(_ value: GLfloat, isLogarithmic: Bool) -> Double {
        return isLogarithmic ? exp(Double(value)) : Double(value)
    }

    private func format(_ value: Double, _ formatter: NumberFormatter) -> String {
        return formatter.string(from: value as NSNumber) ?? "N/A"
    }

    private func unit(_ unit: String) -> String {
        return unit.isEmpty ? "" : " " + unit
    }
}
