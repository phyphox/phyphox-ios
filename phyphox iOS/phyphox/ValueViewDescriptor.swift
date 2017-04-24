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
    
    init(label: String, translation: ExperimentTranslationCollection?, requiresAnalysis: Bool, size: Double, scientific: Bool, precision: Int, unit: String?, factor: Double, buffer: DataBuffer) {
        self.scientific = scientific
        self.precision = precision
        self.unit = unit
        self.factor = factor
        self.buffer = buffer
        self.size = size
        
        super.init(label: label, translation: translation, requiresAnalysis: requiresAnalysis)
    }
    
    override func generateViewHTMLWithID(_ id: Int) -> String {
        return "<div style=\"font-size:105%;\" class=\"valueElement\" id=\"element\(id)\"><span class=\"label\">\(localizedLabel)</span><span class=\"value\"><span class=\"valueNumber\" style=\"font-size:\(100*size)%;\"></span> \(unit ?? "")</span></div>"
    }
    
    override func setValueHTMLWithID(_ id: Int) -> String {
        if scientific {
            return "function (x) { $(\"#element\(id) .value .valueNumber\").text((x*\(factor)).toExponential(\(precision))) }"
        }
        else {
            return "function (x) { $(\"#element\(id) .value .valueNumber\").text((x*\(factor)).toFixed(\(precision))) }"
        }
    }
}
