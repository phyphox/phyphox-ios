//
//  DropdownViewDescriptor.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 24.10.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

struct DropdownViewMap: Equatable {
    let value: String
    let replacement: String
}

struct DropdownViewDescriptor: ViewDescriptor, Equatable {
    var label: String
    let defaultValue: Double?
    let buffer: DataBuffer
    let mappings: [DropdownViewMap]
    
    var value: Double {
        return buffer.last ?? 0.0
    }
    
    var translation: ExperimentTranslationCollection?
    
    init(label: String, defaultValue: Double?, buffer: DataBuffer, mappings: [DropdownViewMap], translation: ExperimentTranslationCollection? = nil) {
        self.label = label
        self.defaultValue = defaultValue
        self.buffer = buffer
        self.mappings = mappings
        self.translation = translation
    }
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        return ""
    }
    
    
}
