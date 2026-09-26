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
    var visibilityBuffer: DataBuffer? { get }

    func generateViewHTMLWithID(_ id: Int) -> String
    func generateDataCompleteHTMLWithID(_ id: Int) -> String
    func setDataHTMLWithID(_ id: Int) -> String
}

extension ViewDescriptor {
    var localizedLabel: String {
        return translation?.localizeString(label) ?? label
    }

    ///Since file format 1.21 the label may be left out (absent or empty) on value, edit, toggle, dropdown, slider,
    ///graph, camera-gui and depth-gui: the caption and its space are omitted (groups.md, "Labels in narrow columns")
    var hasLabel: Bool {
        return !localizedLabel.isEmpty
    }

    ///The label span of the web markup, only with a label (phyphox-webinterface readme.md, "The view layout")
    func labelSpanHTML() -> String {
        return hasLabel ? "<span class=\"label\">\(localizedLabel)</span>" : ""
    }

    ///The class that puts the label above the control in the web interface
    func labelLayoutClass(verticalLayout: Bool) -> String {
        return hasLabel && verticalLayout ? " verticalLayout" : ""
    }

    func generateDataCompleteHTMLWithID(_ id: Int) -> String {
        return "function() {}"
    }

    func setDataHTMLWithID(_ id: Int) -> String {
        return "function(x) {}"
    }

}

protocol ResourceViewDescriptor: ViewDescriptor {
    var resources: [String] { get }
}
