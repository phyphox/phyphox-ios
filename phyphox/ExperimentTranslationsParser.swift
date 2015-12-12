//
//  ExperimentTranslationsParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import UIKit

final class ExperimentTranslationsParser: ExperimentMetadataParser {
    let translations: [NSDictionary]?
    
    required init(_ data: NSDictionary) {
        translations = getElementsWithKey(data, key: "translation") as! [NSDictionary]?
    }
    
    /**
     - returns: `nil` if no translations where found, otherwise a dictionary with the format `[locale: translation]`
     */
    func parse() -> [String: ExperimentTranslation]? {
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
                        let translated = dict[XMLDictionaryTextKey] as! String
                        let originalText = (dict[XMLDictionaryAttributesKey] as! [String: String])["original"]!
                        
                        strings[originalText] = translated
                    }
                }
                else if key as! String == XMLDictionaryAttributesKey {
                    locale = (value as! [String: String])["locale"]!
                }
                else {
                    print("Invalid translation: \(value)")
                    continue
                }
            }
            
            let tr = ExperimentTranslation(withLocale: locale, strings: (strings.count > 0 ? strings : nil), titleString: title, descriptionString: description, categoryString: category)
            
            trs[locale] = tr
            
        }
        
        return (trs.count > 0 ? trs : nil)
    }
}
