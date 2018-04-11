//
//  ExperimentTranslationsParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

final class ExperimentTranslationsParser: ExperimentMetadataParser {
    let translations: [NSDictionary]?
    var defaultLanguage = ""
    
    init (_ data: NSDictionary, defaultLanguage: String) {
        translations = getElementsWithKey(data, key: "translation") as! [NSDictionary]?
        self.defaultLanguage = defaultLanguage
    }
    
    required convenience init(_ data: NSDictionary) {
        self.init(data)
    }
    
    /**
     - returns: `nil` if no translations where found
     */
    func parse() throws -> ExperimentTranslationCollection? {
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
            var links: [String: String] = [:]
            
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
                        description = translated.replacingOccurrences(of: "(?m)((?:^\\s+)|(?:\\s+$))", with: "\n", options: NSString.CompareOptions.regularExpression, range: nil)
                    }
                    else {
                        throw SerializationError.invalidExperimentFile(message: "Invalid metadata type: \(metadataType)")
                    }
                }
                else if key as! String == "string" {
                    for dict in getElemetArrayFromValue(value as AnyObject) as! [NSDictionary] {
                        let translated = dict[XMLDictionaryTextKey] as? String ?? ""
                        let originalText = (dict[XMLDictionaryAttributesKey] as! [String: String])["original"]!
                        
                        strings[originalText] = translated
                    }
                }
                else if key as! String == "link" {
                    for dict in getElemetArrayFromValue(value as AnyObject) as! [NSDictionary] {
                        let url = dict[XMLDictionaryTextKey] as? String ?? ""
                        let label = (dict[XMLDictionaryAttributesKey] as! [String: String])["label"]!
                        
                        if url != "" {
                            links[label] = url
                        }
                    }
                }
                else if key as! String == XMLDictionaryAttributesKey {
                    locale = (value as! [String: String])["locale"]!
                }
                else if key as! String == "__count" || key as! String == "__index" {
                    continue
                }
                else {
                    throw SerializationError.invalidExperimentFile(message: "Invalid translation: \(value)")
                }
            }
            
            let tr = ExperimentTranslation(withLocale: locale, strings: strings, titleString: title, descriptionString: description, categoryString: category, links: links)
            
            trs[locale] = tr
            
        }
        
        return (trs.count > 0 ? ExperimentTranslationCollection(translations: trs, defaultLanguageCode: defaultLanguage) : nil)
    }
}
