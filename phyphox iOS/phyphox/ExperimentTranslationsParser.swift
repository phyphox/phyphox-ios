//
//  ExperimentTranslationsParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

final class ExperimentTranslationsParser: ExperimentMetadataParser {
    let translations: [NSDictionary]?
    
    required init(_ data: NSDictionary) {
        translations = getElementsWithKey(data, key: "translation") as! [NSDictionary]?
    }
    
    /**
     - returns: `nil` if no translations where found
     */
    func parse() -> ExperimentTranslationCollection? {
        if translations == nil {
            return nil
        }
        
        var trs: [String: ExperimentTranslation] = [:]
        
        for translation in translations! {
            var locale: String = ""
            
            var description: String = ""
            var title: String = ""
            var category: String = ""
            
            var strings: [String: String] = [:]
            
            for (key, value) in translation {
                if let translated = value as? String {
                    let metadataType = key as! String
                    
                    if metadataType == "title" {
                        title = translated
                    }
                    else if metadataType == "category" {
                        category = translated
                    }
                    else if metadataType == "description" {
                        description = translated
                    }
                    else {
                        print("Error! Invalid metadata type: \(metadataType)")
                        continue
                    }
                }
                else if key as! String == "string" {
                    for dict in getElemetArrayFromValue(value) as! [NSDictionary] {
                        let translated = dict[XMLDictionaryTextKey] as? String ?? ""
                        let originalText = (dict[XMLDictionaryAttributesKey] as! [String: String])["original"]!
                        
                        strings[originalText] = translated
                    }
                }
                else if key as! String == XMLDictionaryAttributesKey {
                    locale = (value as! [String: String])["locale"]!
                }
                else if key as! String == "__count" || key as! String == "__index" {
                    continue
                }
                else {
                    print("Invalid translation: \(value)")
                    continue
                }
            }
            
            let tr = ExperimentTranslation(withLocale: locale, strings: (strings.count > 0 ? strings : nil), titleString: title, descriptionString: description, categoryString: category)
            
            trs[locale] = tr
            
        }
        
        //TODO: modify phyphox file format to allow specification of default language code
        return (trs.count > 0 ? ExperimentTranslationCollection(translations: trs, defaultLanguageCode: "en") : nil)
    }
}
