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
    
    init(label: String, translation: ExperimentTranslationCollection?, scientific: Bool, precision: Int, unit: String?, factor: Double, buffer: DataBuffer) {
        self.scientific = scientific
        self.precision = precision
        self.unit = unit
        self.factor = factor
        self.buffer = buffer
        
        super.init(label: label, translation: translation)
    }
    
    override func generateViewHTMLWithID(id: Int) -> String {
        return "<div style=\\\"font-size:12;\\\" class=\\\"valueElement\\\" id=\\\"element\(id)\\\"><span class=\\\"label\\\">\(localizedLabel)</span><span class=\\\"value\\\"></span></div>"
    }
    
    override func setValueHTMLWithID(id: Int) -> String {
        if scientific {
            return "function (x) { $(\"#element\(id) .value\").text((x*\(factor)).toExponential(\(precision))+\" \(unit ?? "")\") }"
        }
        else {
            return "function (x) { $(\"#element\(id) .value\").text((x*\(factor)).toFixed(\(precision))+\" \(unit ?? "")\") }"
        }
    }
}
