//
//  ExperimentTranslationCollection.swift
//  phyphox
//
//  Created by Jonas Gessner on 29.03.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//


import Foundation

final class ExperimentTranslationCollection {
    private let translations: [String: ExperimentTranslation]?
    
    private var selectedLanguageCode: String?
    
    private(set) var selectedTranslation: ExperimentTranslation?
    
    init(translations: [String: ExperimentTranslation]?, defaultLanguageCode: String) {
        self.translations = translations
        
        for code in  NSLocale.preferredLanguages() {
            if code == defaultLanguageCode {
                selectedLanguageCode = defaultLanguageCode
                break
            }
            
            if let selected = translations?[code] {
                selectedLanguageCode = code
                selectedTranslation = selected
                break
            }
        }
    }
    
    func localize(string: String) -> String {
        return selectedTranslation?.translatedStrings?[string] ?? string
    }
}
