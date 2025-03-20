//
//  ValueViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import CoreGraphics

struct ValueViewMap: Equatable {
    let range: ClosedRange<Double>

    let replacement: String
}

struct ValueViewDescriptor: ViewDescriptor, Equatable {
    let scientific: Bool
    let precision: Int
    let unit: String?
    let factor: Double
    let buffer: DataBuffer
    let size: Double
    let mappings: [ValueViewMap]
    let positiveUnit: String?
    let negetiveUnit: String?
    
    var gpsFormat: GpsFormat?

    let label: String
    let color: UIColor
    let translation: ExperimentTranslationCollection?

    var localizedUnit: String? {
        if unit == nil {
            return nil
        }
        return translation?.localizeString(unit!) ?? unit!
    }
    
    var localizedPositiveUnit: String? {
        if unit == nil {
            return nil
        }
        return translation?.localizeString(positiveUnit!) ?? positiveUnit!
    }
    
    var localizedNegativeUnit: String? {
        if unit == nil {
            return nil
        }
        return translation?.localizeString(negetiveUnit!) ?? negetiveUnit!
    }
    
    init(label: String, color: UIColor, translation: ExperimentTranslationCollection?, size: Double, scientific: Bool, precision: Int, unit: String?, factor: Double, buffer: DataBuffer, mappings: [ValueViewMap], positiveUnit: String?, negativeUnit: String?, gpsFormat: String?) {
        self.scientific = scientific
        self.precision = precision
        self.unit = unit
        self.factor = factor
        self.buffer = buffer
        self.size = size

        let translatedMappings = mappings.compactMap { map in (translation?.localizeString(map.replacement) ?? map.replacement).map { ValueViewMap(range: map.range, replacement: $0) } }
        
        self.mappings = translatedMappings

        self.label = label
        self.color = color
        self.translation = translation
        
        self.positiveUnit = positiveUnit
        self.negetiveUnit = negativeUnit
        
        switch gpsFormat {
            case "float":
                self.gpsFormat = .FLOAT
            case "degree-minutes":
                self.gpsFormat =  .DEGREE_MINUTES
            case "degree-minutes-seconds":
                self.gpsFormat =  .DEGREE_MINUTES_SECONDS
            default:
                self.gpsFormat = nil
        }
        
    }
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        return "<div style=\"font-size:105%;color:#\(color.hexStringValue!)\" class=\"valueElement adjustableColor\" id=\"element\(id)\"><span class=\"label\">\(localizedLabel)</span><span class=\"value\"><span class=\"valueNumber\" style=\"font-size:\(100*size)%;\"></span> <span class=\"valueUnit\">\(localizedUnit ?? "")</span></span></div>"
    }
    
    func setDataHTMLWithID(_ id: Int) -> String {
        let bufferName = buffer.name.replacingOccurrences(of: "\"", with: "\\\"")
        var mappingCode = "if (isNaN(x) || x == null) { v = \"-\" }"
        for mapping in mappings {
            let str = mapping.replacement.replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "\\\"") // addingPercentEncoding() !???

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
        return "function (data) {" +
               "    if (!data.hasOwnProperty(\"\(bufferName)\"))" +
               "        return;" +
               "    var x = data[\"\(bufferName)\"][\"data\"][data[\"\(bufferName)\"][\"data\"].length-1];" +
               "    var v = null;" +
               mappingCode +
               "    var valueElement = document.getElementById(\"element\(id)\").getElementsByClassName(\"value\")[0];" +
               "     var valueNumber = valueElement.getElementsByClassName(\"valueNumber\")[0];" +
               "     var valueUnit = valueElement.getElementsByClassName(\"valueUnit\")[0];" +
               "    if (v == null) {" +
               "        v = (x*\(factor)).to\(scientific ? "Exponential" : "Fixed")(\(precision));" +
               "        valueUnit.textContent = \"\(localizedUnit ?? "")\";" +
               "    } else { " +
               "        valueUnit.textContent = \"\";" +
               "    } " +
               "    valueNumber.textContent = v;" +
               "}"
    }
}
