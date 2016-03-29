//
//  ViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

public class ViewDescriptor {
    private let label: String
    weak var translation: ExperimentTranslationCollection?
    
    var localizedLabel: String {
        return translation?.localize(label) ?? label
    }
    
    init(label: String, translation: ExperimentTranslationCollection?) {
        self.label = label
        self.translation = translation
    }
}
