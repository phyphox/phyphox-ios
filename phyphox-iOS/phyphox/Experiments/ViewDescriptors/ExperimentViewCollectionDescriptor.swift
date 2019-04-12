//
//  ExperimentViewCollectionDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import CoreGraphics

/**
 Represents an experiment view, which contais zero or more views, represented by view descriptors.
 */
final class ExperimentViewCollectionDescriptor: ViewDescriptor {
    let views: [ViewDescriptor]

    let label: String
    let translation: ExperimentTranslationCollection?

    init(label: String, translation: ExperimentTranslationCollection?, views: [ViewDescriptor]) {
        self.views = views
        
        self.label = label
        self.translation = translation
    }
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        return ""
    }
}

extension ExperimentViewCollectionDescriptor: Equatable {
    static func == (lhs: ExperimentViewCollectionDescriptor, rhs: ExperimentViewCollectionDescriptor) -> Bool {
        return lhs.views.elementsEqual(rhs.views) { (l, r) -> Bool in
            if let ll = l as? InfoViewDescriptor {
                guard let rr = r as? InfoViewDescriptor, ll == rr else {
                    return false
                }
            }
            else if let ll = l as? ValueViewDescriptor {
                guard let rr = r as? ValueViewDescriptor, ll == rr else {
                    return false
                }
            }
            else if let ll = l as? GraphViewDescriptor {
                guard let rr = r as? GraphViewDescriptor, ll == rr else {
                    return false
                }
            }
            else if let ll = l as? EditViewDescriptor {
                guard let rr = r as? EditViewDescriptor, ll == rr else {
                    return false
                }
            }
            else if let ll = l as? ButtonViewDescriptor {
                guard let rr = r as? ButtonViewDescriptor, ll == rr else {
                    return false
                }
            }
            else if let ll = l as? SeparatorViewDescriptor {
                guard let rr = r as? SeparatorViewDescriptor, ll == rr else {
                    return false
                }
            }
            else {
                return false
            }
            return true
        }
    }
}
