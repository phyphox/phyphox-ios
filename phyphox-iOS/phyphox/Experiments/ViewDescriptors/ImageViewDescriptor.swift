//
//  ImageViewDescriptor.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 27.06.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

struct ImageViewDescriptor: ViewDescriptor, Equatable {
    var src: String
    
    let label = ""
    
    var translation: ExperimentTranslationCollection?
    
    init(src: String, translation: ExperimentTranslationCollection?) {
        self.src = src
        self.translation = translation
    }
    
    // TODO crete view for image
    func generateViewHTMLWithID(_ id: Int) -> String {
        let warningText = localize("remoteImageWarning").replacingOccurrences(of: "\"", with: "\\\"")
        return "<div style=\"font-size: 105%;\" class=\"graphElement\" id=\"element\(id)\"><span class=\"label\" onclick=\"toggleExclusive(\(id));\">\(localizedLabel)</span><div class=\"warningIcon\" onclick=\"alert('\(warningText)')\"></div></div>"
    }
    
    
}
