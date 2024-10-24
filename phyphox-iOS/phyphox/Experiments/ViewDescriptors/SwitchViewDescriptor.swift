//
//  SwitchViewDescriptor.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 21.10.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

struct SwitchViewDescriptor: ViewDescriptor, Equatable {
    
    let defaultValue: Double
    let buffer: DataBuffer
    let label: String
    let translation: ExperimentTranslationCollection?
    
    var value: Double {
        return buffer.last ?? defaultValue
    }
    
    init(label: String, translation: ExperimentTranslationCollection?, defaultValue: Double, buffer: DataBuffer) {
        
        self.defaultValue = defaultValue
        self.buffer = buffer
        self.label = label
        self.translation = translation
    }
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        return ""
    }
    
    
}
