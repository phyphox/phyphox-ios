//
//  ViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

public class ViewDescriptor {
    private let label: String
    let requiresAnalysis: Bool
    weak var translation: ExperimentTranslationCollection?
    
    var localizedLabel: String {
        return translation?.localize(label) ?? label
    }
    
    init(label: String, translation: ExperimentTranslationCollection?, requiresAnalysis: Bool = false) {
        self.label = label
        self.translation = translation
        self.requiresAnalysis = requiresAnalysis
    }
    
    func generateViewHTMLWithID(id: Int) -> String {
        fatalError("Override this method")
    }
    
    func generateDataCompleteHTMLWithID(id: Int) -> String {
        return "function() {}"
    }
    
    func setValueHTMLWithID(id: Int) -> String {
        return "function(x) {}"
    }
    
    func setDataXHTMLWithID(id: Int) -> String {
        return "function(x) {}"
    }
    
    func setDataYHTMLWithID(id: Int) -> String {
        return "function(y) {}"
    }
}
