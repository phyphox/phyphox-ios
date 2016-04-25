//
//  EditViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//


import Foundation
import CoreGraphics

final class EditViewDescriptor: ViewDescriptor {
    let signed: Bool
    let decimal: Bool
    let unit: String?
    let factor: Double
    
    let defaultValue: Double
    let buffer: DataBuffer
    
    var value: Double {
        return buffer.last ?? defaultValue
    }
    
    init(label: String, translation: ExperimentTranslationCollection?, signed: Bool, decimal: Bool, unit: String?, factor: Double, defaultValue: Double, buffer: DataBuffer) {
        self.signed = signed
        self.decimal = decimal
        self.unit = unit
        self.factor = factor
        self.defaultValue = defaultValue
        self.buffer = buffer
        
        super.init(label: label, translation: translation)
    }
    
    override func generateViewHTMLWithID(id: Int) -> String {
        //Construct value restrictions in HTML5
        var restrictions = ""
        
        if (!signed) {
            restrictions += "min=\\\"0\\\" "
        }
        if (!decimal) {
            restrictions += "step=\\\"1\\\" "
        }
        
        return "<div class=\\\"editElement\\\" id=\\\"element\(id)\\\"><span class=\\\"label\\\">\(localizedLabel)</span><input onchange=\\\"$.getJSON('control?cmd=set&buffer=\(buffer.name)&value='+$(this).val()/\(factor))\\\" type=\\\"number\\\" class=\\\"value\\\" \(restrictions) /><span class=\\\"unit\\\">\(unit ?? "")</span></div>"
    }
    
    override func setValueHTMLWithID(id: Int) -> String {
        return "function (x) { if (!$(\"#element\(id) .value\").is(':focus')) $(\"#element\(id) .value\").val((x*\(factor))) }"
    }
}

