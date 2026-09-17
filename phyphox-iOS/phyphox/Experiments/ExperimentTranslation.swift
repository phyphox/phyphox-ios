//
//  ExperimentTranslation.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

/// A link element inside a translation block, matched by label against the base links (phyphox-docs
/// translation-link-matching); an absent URL or highlight inherits from the replaced base link.
struct ExperimentTranslatedLink: Equatable {
    let label: String
    let translation: String?
    let url: URL?
    let highlighted: Bool?

    var removesBaseLink: Bool {
        return translation == nil && url == nil && highlighted == nil
    }
}

struct ExperimentTranslation: Equatable {
    let locale: String

    let titleString: String?
    let descriptionString: String?
    let categoryString: String?

    let translatedStrings: [String: String]
    let translatedLinks: [ExperimentTranslatedLink]

    init(withLocale locale: String, strings: [String: String], titleString: String?, descriptionString: String?, categoryString: String?, links: [ExperimentTranslatedLink]) {
        self.locale = locale
        self.descriptionString = descriptionString
        self.categoryString = categoryString
        self.titleString = titleString
        translatedStrings = strings
        translatedLinks = links
    }
}
