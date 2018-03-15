//
//  ViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

open class ViewDescriptor {
    private let label: String
    weak var translation: ExperimentTranslationCollection?
    
    var localizedLabel: String {
        return translation?.localize(label) ?? label
    }
    
    init(label: String, translation: ExperimentTranslationCollection?) {
        self.label = label
        self.translation = translation
    }
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        fatalError("Override this method")
    }
    
    func generateDataCompleteHTMLWithID(_ id: Int) -> String {
        return "function() {}"
    }
    
    func setValueHTMLWithID(_ id: Int) -> String {
        return "function(x) {}"
    }
    
    func setDataXHTMLWithID(_ id: Int) -> String {
        return "function(x) {}"
    }
    
    func setDataYHTMLWithID(_ id: Int) -> String {
        return "function(y) {}"
    }
}
