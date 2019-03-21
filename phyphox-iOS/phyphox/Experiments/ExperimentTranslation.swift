//
//  ExperimentTranslation.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

struct ExperimentTranslation: Equatable {
    let locale: String
    
    let titleString: String?
    let descriptionString: String?
    let categoryString: String?
    
    let translatedStrings: [String: String]
    let translatedLinks: [String: URL]
    
    init(withLocale locale: String, strings: [String: String], titleString: String?, descriptionString: String?, categoryString: String?, links: [String: URL]) {
        self.locale = locale
        self.descriptionString = descriptionString
        self.categoryString = categoryString
        self.titleString = titleString
        translatedStrings = strings
        translatedLinks = links
    }
}
