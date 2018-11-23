//
//  ExperimentTranslationCollection.swift
//  phyphox
//
//  Created by Jonas Gessner on 29.03.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

struct ExperimentTranslationCollection: Equatable {
    private let translations: [String: ExperimentTranslation]
    let selectedTranslation: ExperimentTranslation?
    
    init(translations: [String: ExperimentTranslation], defaultLanguageCode: String) {
        self.translations = translations
    
        let selectedLanguageCode = Locale.current.languageCode?.components(separatedBy: "-")[0] ?? "en"
        
        selectedTranslation = translations[selectedLanguageCode]
    }
    
    func localize(_ string: String) -> String {
        return selectedTranslation?.translatedStrings[string] ?? string
    }
}
