//
//  ValueViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation
import CoreGraphics

final class ValueViewDescriptor: ViewDescriptor {
    let scientific: Bool
    let precision: Int
    let unit: String?
    let factor: Double
    let buffer: DataBuffer
    let size: Double
    let mappings: [(min: Double, max: Double, str: String)]
    
    init(label: String, translation: ExperimentTranslationCollection?, requiresAnalysis: Bool, size: Double, scientific: Bool, precision: Int, unit: String?, factor: Double, buffer: DataBuffer, mappings: [(min: Double, max: Double, str: String)]) {
        self.scientific = scientific
        self.precision = precision
        self.unit = unit
        self.factor = factor
        self.buffer = buffer
        self.size = size
        
        var translatedMappings: [(min: Double, max: Double, str: String)] = []
        for mapping in mappings {
            translatedMappings.append((min: mapping.min, max: mapping.max, str: translation?.localize(mapping.str) ?? mapping.str))
        }
        
        self.mappings = translatedMappings
        
        super.init(label: label, translation: translation, requiresAnalysis: requiresAnalysis)
    }
    
    override func generateViewHTMLWithID(_ id: Int) -> String {
        return "<div style=\"font-size:105%;\" class=\"valueElement\" id=\"element\(id)\"><span class=\"label\">\(localizedLabel)</span><span class=\"value\"><span class=\"valueNumber\" style=\"font-size:\(100*size)%;\"></span> <span=\"valueUnit\">\(unit ?? "")</span></span></div>"
    }
    
    override func setValueHTMLWithID(_ id: Int) -> String {
        var mappingCode = "if (isNaN(x) || x == null) { v = \"-\" }"
        for mapping in mappings {
            let str = mapping.str.replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
            if mapping.max.isFinite && mapping.min.isFinite {
                mappingCode += "else if (x >= \(mapping.min) && x <= \(mapping.max)) {v = \"\(str)\";}"
            } else if mapping.max.isFinite {
                mappingCode += "else if (x <= \(mapping.max)) {v = \"\(str)\";}"
            } else if mapping.min.isFinite {
                mappingCode += "else if (x >= \(mapping.min)) {v = \"\(str)\";}"
            } else {
                mappingCode += "else if (true) {v = \"\(str)\";}"
            }
        }
        return "function (x) {" +
               "    var v = null;" +
               mappingCode +
               "    if (v == null) {" +
               "        v = (x*\(factor)).to\(scientific ? "Exponential" : "Fixed")(\(precision));" +
               "        $(\"#element\(id) .value .valueUnit\").text(\"\(unit ?? "")\");" +
               "    } else { " +
               "        $(\"#element\(id) .value .valueUnit\").text(\"\");" +
               "    } " +
               "    $(\"#element\(id) .value .valueNumber\").text(v);" +
               "}"
    }
}
