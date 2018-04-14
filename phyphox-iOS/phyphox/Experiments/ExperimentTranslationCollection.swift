//
//  ExperimentTranslationCollection.swift
//  phyphox
//
//  Created by Jonas Gessner on 29.03.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

final class ExperimentTranslationCollection {
    private let translations: [String: ExperimentTranslation]
    let selectedTranslation: ExperimentTranslation?
    
    init(translations: [String: ExperimentTranslation], defaultLanguageCode: String) {
        self.translations = translations

        let preferredLanguageCodes = Locale.preferredLanguages.lazy.map({ $0.components(separatedBy: "-")[0] })

        let selectedLanguageCode = preferredLanguageCodes.first(where: { translations.keys.contains($0) }) ?? defaultLanguageCode
        
        selectedTranslation = translations[selectedLanguageCode]
    }
    
    func localize(_ string: String) -> String {
        return selectedTranslation?.translatedStrings[string] ?? string
    }
}
