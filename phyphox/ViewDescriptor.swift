//
//  ViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreGraphics

public class ViewDescriptor {
    let label: String
    let labelSize: CGFloat
    
    init(label: String, labelSize: CGFloat) {
        self.label = label
        self.labelSize = labelSize
    }
}
