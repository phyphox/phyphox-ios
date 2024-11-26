//
//  DropdownViewDescriptor.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 24.10.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

struct DropdownViewDescriptor: ViewDescriptor, Equatable {
    var label: String
    
    let dropDownList: String
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
