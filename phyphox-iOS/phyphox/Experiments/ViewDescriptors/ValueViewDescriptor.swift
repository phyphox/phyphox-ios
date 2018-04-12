//
//  ValueViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import CoreGraphics

struct ValueViewMap {
    let range: ClosedRange<Double>

    let replacement: String
}

final class ValueViewDescriptor: ViewDescriptor {
    let scientific: Bool
    let precision: Int
    let unit: String?
    let factor: Double
    let buffer: DataBuffer
    let size: Double
    let mappings: [ValueViewMap]
    
    init(label: String, translation: ExperimentTranslationCollection?, size: Double, scientific: Bool, precision: Int, unit: String?, factor: Double, buffer: DataBuffer, mappings: [ValueViewMap]) {
        self.scientific = scientific
        self.precision = precision
        self.unit = unit
        self.factor = factor
        self.buffer = buffer
        self.size = size

        let translatedMappings = mappings.compactMap { map in (translation?.localize(map.replacement)).map { ValueViewMap(range: map.range, replacement: $0) } }
        
        self.mappings = mappings + translatedMappings
        
        super.init(label: label, translation: translation)
    }
    
    override func generateViewHTMLWithID(_ id: Int) -> String {
        return "<div style=\"font-size:105%;\" class=\"valueElement\" id=\"element\(id)\"><span class=\"label\">\(localizedLabel)</span><span class=\"value\"><span class=\"valueNumber\" style=\"font-size:\(100*size)%;\"></span> <span=\"valueUnit\">\(unit ?? "")</span></span></div>"
    }
    
    override func setValueHTMLWithID(_ id: Int) -> String {
        var mappingCode = "if (isNaN(x) || x == null) { v = \"-\" }"
        for mapping in mappings {
            let str = mapping.replacement.replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;") // addingPercentEncoding() !???

            if mapping.range.upperBound.isFinite && mapping.range.lowerBound.isFinite {
                mappingCode += "else if (x >= \(mapping.range.lowerBound) && x <= \(mapping.range.upperBound)) {v = \"\(str)\";}"
            }
            else if mapping.range.upperBound.isFinite {
                mappingCode += "else if (x <= \(mapping.range.upperBound)) {v = \"\(str)\";}"
            }
            else if mapping.range.lowerBound.isFinite {
                mappingCode += "else if (x >= \(mapping.range.lowerBound)) {v = \"\(str)\";}"
            }
            else {
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
