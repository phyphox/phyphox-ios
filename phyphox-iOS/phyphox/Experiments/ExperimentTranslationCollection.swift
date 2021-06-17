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

    static func getLanguageRating(languageCode: String?) -> Int {
        guard let languageCode = languageCode, languageCode != "" else {
            return 1
        }
        
        var score = 0
        
        let parts = languageCode.lowercased().components(separatedBy: CharacterSet(charactersIn: "-_"))
        let baseLanguage: String
        let region: String
        let script: String
        
        if parts.count > 0 {
            baseLanguage = parts[0]
        } else {
            baseLanguage = ""
        }
        
        if parts.count > 1 {
            region = parts[parts.count-1]
            if parts.count > 2 {
                script = parts[1]
            } else {
                script = region
            }
        } else {
            region = ""
            script = ""
        }

        let appLocale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
        let currentBaseLanguage = appLocale.languageCode?.lowercased()
        let currentRegion = appLocale.regionCode?.lowercased()
        let currentScript = appLocale.scriptCode?.lowercased()
        
        if baseLanguage == currentBaseLanguage {
            score += 100
        }
        
        if region == currentRegion {
            score += 20
        }
        
        if script == currentScript {
            score += 10
        }
        
        if baseLanguage == "en" {
            score += 2
        }
        
        return score
    }
    
    init(translations: [String: ExperimentTranslation], defaultLanguageCode: String) {
        self.translations = translations
        
        var selectedLanguageCode = defaultLanguageCode
        var bestScore = ExperimentTranslationCollection.getLanguageRating(languageCode: defaultLanguageCode)
        for code in translations.keys {
            let score = ExperimentTranslationCollection.getLanguageRating(languageCode: code)
            if score > bestScore {
                bestScore = score
                selectedLanguageCode = code
            }
        }
        
        selectedTranslation = translations[selectedLanguageCode]
    }
    
    func localizeString(_ string: String) -> String {
        if let translated = selectedTranslation?.translatedStrings[string] {
            return translated
        }
        if string.hasPrefix("[[") && string.hasSuffix("]]") {
            let start = string.index(string.startIndex, offsetBy: 2)
            let stop = string.index(string.endIndex, offsetBy: -2)
            return localize("common_" + string[start ..< stop])
        }
        return string
    }
    
    func localizeLink(_ string: String, fallback: URL) -> URL {
        return selectedTranslation?.translatedLinks[string] ?? fallback
    }
}
