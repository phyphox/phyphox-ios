//
//  depthGUIDescriptor.swift
//  phyphox
//
//  Created by Sebastian Staacks on 13.10.21.
//  Copyright © 2021 RWTH Aachen. All rights reserved.
//

import Foundation

struct DepthGUIViewDescriptor: ViewDescriptor, Equatable {
    let label: String
    let visibilityBuffer: DataBuffer?
    let aspectRatio: CGFloat

    let translation: ExperimentTranslationCollection?

    init(label: String, visibilityBuffer: DataBuffer?, aspectRatio: CGFloat, translation: ExperimentTranslationCollection?) {
        self.label = label
        self.visibilityBuffer = visibilityBuffer
        self.aspectRatio = aspectRatio
        self.translation = translation
    }

    func generateViewHTMLWithID(_ id: Int) -> String {
        let warningText = localize("remoteDepthGUIWarning").replacingOccurrences(of: "\"", with: "\\\"")
        return "<div style=\"font-size: 105%;\" class=\"graphElement\" id=\"element\(id)\"><span class=\"label\" onclick=\"toggleExclusive(\(id));\">\(localizedLabel)</span><div class=\"warningIcon\" onclick=\"alert('\(warningText)')\"></div></div>"
    }
    
    func setDataHTMLWithID(_ id: Int) -> String {
        guard let visibilityLabel = visibilityBuffer?.name else {
                    return ""
                }
        
        return """
                function (data) {
                     if (data.hasOwnProperty(\"\(visibilityLabel)\")) {
                     var x = data[\"\(visibilityLabel)\"][\"data\"][data[\"\(visibilityLabel)\"][\"data\"].length-1];
                     var depthGuiElement = document.getElementById(\"element\(id)\");
                     if (x <= 0.0 || x.length == 0) {
                         depthGuiElement.style.display = \"none\";
                     } else {
                         depthGuiElement.style.display = \"block\";
                     }
                }
            """
    }
}
