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
            
            //If the preferred language matches a translation block, this always takes precedence and so we select this and are done. Translations will fall back to the default language anyways...
            if let selected = translations?[languageCode] {
                selectedLanguageCode = languageCode
                selectedTranslation = selected
                break
            }
            
            //If we did not find a translation block for the preferred language, but it matches the defaultLanguage, we can use these strings without a translation
            if languageCode == defaultLanguageCode {
                selectedLanguageCode = defaultLanguageCode
                break
            }
            
        }
    }
    
    func localize(string: String) -> String {
        return selectedTranslation?.translatedStrings?[string] ?? string
    }
}
