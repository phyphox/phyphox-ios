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
            let languageCode = code.componentsSeparatedByString("-")[0]
            if languageCode == defaultLanguageCode {
                selectedLanguageCode = defaultLanguageCode
                break
            }
            
            if let selected = translations?[languageCode] {
                selectedLanguageCode = languageCode
                selectedTranslation = selected
                break
            }
        }
    }
    
    func localize(string: String) -> String {
        return selectedTranslation?.translatedStrings?[string] ?? string
    }
}
