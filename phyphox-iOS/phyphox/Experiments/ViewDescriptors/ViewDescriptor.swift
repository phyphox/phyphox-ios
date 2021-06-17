//
//  ViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

protocol ViewDescriptor {
    var label: String { get }
    var translation: ExperimentTranslationCollection? { get }

    func generateViewHTMLWithID(_ id: Int) -> String
    func generateDataCompleteHTMLWithID(_ id: Int) -> String
    func setDataHTMLWithID(_ id: Int) -> String
}

extension ViewDescriptor {
    var localizedLabel: String {
        return translation?.localizeString(label) ?? label
    }

    func generateDataCompleteHTMLWithID(_ id: Int) -> String {
        return "function() {}"
    }

    func setDataHTMLWithID(_ id: Int) -> String {
        return "function(x) {}"
    }

}
