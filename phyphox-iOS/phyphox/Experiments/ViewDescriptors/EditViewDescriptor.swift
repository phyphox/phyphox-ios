//
//  EditViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import CoreGraphics

struct EditViewDescriptor: ViewDescriptor, Equatable {
    let signed: Bool
    let decimal: Bool
    let unit: Unit //The experiment's unit: a reference to a known unit or text
    let factor: Double
    
    let min: Double
    let max: Double
    
    let defaultValue: Double
    let buffer: DataBuffer
    
    var localizedUnit: String {
        return unit.symbol
    }

    //A referenced unit with a quantity and decimal input (an integer restriction in ft is not one in m)
    var isConvertible: Bool {
        return unit.isConvertible && decimal
    }
    
    var value: Double {
        return buffer.last ?? defaultValue
    }

    let label: String
    //Label on its own line above the field (file format 1.21)
    let verticalLayout: Bool
    let align: InfoViewElementDescriptor.TextAlignment
    let translation: ExperimentTranslationCollection?
    
    var visibilityBuffer : DataBuffer?

    init(label: String, visibilityBuffer : DataBuffer?, translation: ExperimentTranslationCollection?, signed: Bool, decimal: Bool, unit: Unit, factor: Double, min: Double, max: Double, defaultValue: Double, buffer: DataBuffer, verticalLayout: Bool = false, align: InfoViewElementDescriptor.TextAlignment = .left) {
        self.verticalLayout = verticalLayout
        self.align = align
        self.signed = signed
        self.decimal = decimal
        self.unit = unit
        self.factor = factor
        self.min = min
        self.max = max
        self.defaultValue = defaultValue
        self.buffer = buffer

        self.label = label
        self.translation = translation
        self.visibilityBuffer = visibilityBuffer
    }
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        //Construct value restrictions in HTML5
        var restrictions = ""
        
        if (!signed && min < 0) {
            restrictions += "min=\"0\" "
        } else if (min.isFinite) {
            restrictions += "min=\"\(min*factor)\" "
        }
        if (max.isFinite) {
            restrictions += "max=\"\(max*factor)\" "
        }
        if (!decimal) {
            restrictions += "step=\"1\" "
        }
        
        return "<div style=\"font-size: 105%;\" class=\"editElement\(labelLayoutClass(verticalLayout: verticalLayout, align: align))\" id=\"element\(id)\">\(labelSpanHTML())<input onchange=\"ajax('control?cmd=set&buffer=\(buffer.name)&value='+this.value/\(factor))\" type=\"number\" class=\"value\" \(restrictions) /><span class=\"unit\">\(localizedUnit)</span></div>"
    }

    //The remote interface handles the field itself from this (webinterface readme.md, "Value and edit elements"); the
    //limits are in buffer units, as in the file
    func webEditConfig() -> String {
        let config: WebJSON.Object = [
            ("unit", unit.webJSON),
            ("factor", factor),
            ("min", min.isFinite ? min : nil),
            ("max", max.isFinite ? max : nil),
            ("signed", signed),
            ("decimal", decimal),
            ("default", defaultValue.isFinite ? defaultValue : nil)
        ]
        return WebJSON.encode(config)
    }

    func setDataHTMLWithID(_ id: Int) -> String {
        let bufferName = buffer.name.replacingOccurrences(of: "\"", with: "\\\"")
        return "function (data) {" +
            "var valueElement = document.getElementById(\"element\(id)\").getElementsByClassName(\"value\")[0];" +
            "if (!data.hasOwnProperty(\"\(bufferName)\"))" +
            "    return;" +
            "var x = data[\"\(bufferName)\"][\"data\"][data[\"\(bufferName)\"][\"data\"].length-1];" +
            "console.log(\"editElement buffer value is \" +x);" +
            "if (valueElement !== document.activeElement)" +
            "   valueElement.value = (x*\(factor))" +
        "}"
    }
}

