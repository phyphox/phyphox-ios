//
//  InfoViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 15.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

struct InfoViewDescriptor: ViewDescriptor, Equatable {
    let label: String
    let color: UIColor
    let translation: ExperimentTranslationCollection?

    init(label: String, color: UIColor, translation: ExperimentTranslationCollection?) {
        self.label = label
        self.color = color
        self.translation = translation
    }

    func generateViewHTMLWithID(_ id: Int) -> String {
        //TODO: Color
        return "<div style=\"font-size:90%;\" class=\"infoElement\" id=\"element\(id)\"><p>\(localizedLabel)</p></div>"
    }
}
