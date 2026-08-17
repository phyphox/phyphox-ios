//
//  ExperimentTranslation.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

/// A link element inside a translation block. Matched by label against the base links: a matched
/// label replaces the base link in place, an unmatched label is an additional link appended after
/// the base links, and a matched label with nothing but the label removes the base link
/// (translation-link-matching in phyphox-docs). URL and highlight stay optional here because an
/// absent value inherits from the replaced base link.
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
