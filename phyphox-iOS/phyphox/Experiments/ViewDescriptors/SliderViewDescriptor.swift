//
//  SliderViewDescriptor.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 26.11.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation


struct SliderViewDescriptor: ViewDescriptor, Equatable {
    var label: String
    
    let minValue: Double?
    let maxValue: Double?
    let stepSize: Double?
    let defaultValue: Double?
    
    let buffer: DataBuffer
    
    var value: Double {
        return buffer.last ?? 0.0
    }
    
    var translation: ExperimentTranslationCollection?
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        return ""
    }
    
    
}
