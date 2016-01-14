//
//  ValueViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreGraphics

public final class ValueViewDescriptor: ViewDescriptor {
    let scientific: Bool
    let precision: Int
    let unit: String
    let factor: Double
    
    init(label: String, labelSize: CGFloat, scientific: Bool, precision: Int, unit: String, factor: Double) {
        self.scientific = scientific
        self.precision = precision
        self.unit = unit
        self.factor = factor
        
        super.init(label: label, labelSize: labelSize)
    }
}
