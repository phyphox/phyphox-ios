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
    let unit: String?
    let factor: Double
    
    let min: Double
    let max: Double
    
    let defaultValue: Double
    let buffer: DataBuffer
    
    var localizedUnit: String? {
        if unit == nil {
            return nil
        }
        return translation?.localize(unit!) ?? unit!
    }
    
    var value: Double {
        return buffer.last ?? defaultValue
    }
    
    var localizedUnit: String? {
        if unit == nil {
            return nil
        }
        return translation?.localize(unit!) ?? unit!
    }

    let label: String
    let translation: ExperimentTranslationCollection?

    init(label: String, translation: ExperimentTranslationCollection?, signed: Bool, decimal: Bool, unit: String?, factor: Double, min: Double, max: Double, defaultValue: Double, buffer: DataBuffer) {
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
        
        return "<div style=\"font-size: 105%;\" class=\"editElement\" id=\"element\(id)\"><span class=\"label\">\(localizedLabel)</span><input onchange=\"$.getJSON('control?cmd=set&buffer=\(buffer.name)&value='+$(this).val()/\(factor))\" type=\"number\" class=\"value\" \(restrictions) /><span class=\"unit\">\(localizedUnit ?? "")</span></div>"
    }

    func setValueHTMLWithID(_ id: Int) -> String {
        return "function (x) { if (!$(\"#element\(id) .value\").is(':focus')) $(\"#element\(id) .value\").val((x*\(factor))) }"
    }
}

