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
    let precision: Int
    
    let buffer: DataBuffer
    
    var value: Double {
        return buffer.last ?? (defaultValue ?? 0.0)
    }
    
    var translation: ExperimentTranslationCollection?
    
    init(label: String, minValue: Double?, maxValue: Double?, stepSize: Double?, defaultValue: Double?, precision: Int, buffer: DataBuffer, translation: ExperimentTranslationCollection? = nil) {
        self.label = label
        self.minValue = minValue
        self.maxValue = maxValue
        self.stepSize = stepSize
        self.defaultValue = defaultValue
        self.precision = precision
        self.buffer = buffer
        self.translation = translation
    }
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        return ""
    }
    
    
}
