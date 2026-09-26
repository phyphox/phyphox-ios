//
//  ViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import UIKit

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

    ///Whether label and control take the full width - with verticalLayout, or without a label - which is where align applies
    func isFullWidth(verticalLayout: Bool) -> Bool {
        return !hasLabel || verticalLayout
    }

    ///The classes that go with the label handling of the web markup: verticalLayout, and alignCenter or alignRight
    ///where align applies (phyphox-webinterface readme.md, "Labels"); left adds nothing
    func labelLayoutClass(verticalLayout: Bool, align: InfoViewElementDescriptor.TextAlignment = .left) -> String {
        var classes = hasLabel && verticalLayout ? " verticalLayout" : ""
        if isFullWidth(verticalLayout: verticalLayout) {
            switch align {
            case .center: classes += " alignCenter"
            case .right: classes += " alignRight"
            case .left: break
            }
        }
        return classes
    }

    func generateDataCompleteHTMLWithID(_ id: Int) -> String {
        return "function() {}"
    }

    func setDataHTMLWithID(_ id: Int) -> String {
        return "function(x) {}"
    }

}

extension InfoViewElementDescriptor.TextAlignment {
    ///The UIKit alignment; left is .natural like the labels of the full-width layouts (RTL is not supported yet)
    var textAlignment: NSTextAlignment {
        switch self {
        case .left: return .natural
        case .center: return .center
        case .right: return .right
        }
    }

    ///The alignment of a button's content, for a control that spans the row and aligns its text
    var contentHorizontalAlignment: UIControl.ContentHorizontalAlignment {
        switch self {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }

    ///The CSS value of the info element's inline text-align, as Android emits it
    var cssTextAlign: String {
        switch self {
        case .left: return "start"
        case .center: return "center"
        case .right: return "end"
        }
    }
}

protocol ResourceViewDescriptor: ViewDescriptor {
    var resources: [String] { get }
}
