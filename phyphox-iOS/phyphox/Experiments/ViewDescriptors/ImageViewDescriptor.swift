//
//  ImageViewDescriptor.swift
//  phyphox
//
//  Created by Sebastian Staacks on 08.05.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

struct ImageViewDescriptor: ResourceViewDescriptor, Equatable {
    var resources: [String]
    
    let label = ""
    var translation: ExperimentTranslationCollection? = nil
    var visibilityBuffer: DataBuffer?
        
    let src: String
    let scale: CGFloat
    
    let lightFilter: ImageViewElementDescriptor.Filter
    let darkFilter: ImageViewElementDescriptor.Filter
    
    init(visibilityBuffer: DataBuffer?, src: String, scale: CGFloat, darkFilter: ImageViewElementDescriptor.Filter, lightFilter: ImageViewElementDescriptor.Filter) {
        self.visibilityBuffer = visibilityBuffer
        self.src = src
        self.scale = scale
        self.darkFilter = darkFilter
        self.lightFilter = lightFilter
        resources = [src]
    }
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        return "<div class=\"imageElement\" id=\"element\(id)\"><img style=\"width: \(scale*100.0)% \" class=\"lightFilter_\(lightFilter.rawValue) darkFilter_\(darkFilter.rawValue)\" src=\"res?src=\(src)\"></p></div>"
    }
    
    func setDataHTMLWithID(_ id: Int) -> String {
        guard let visibilityLabel = visibilityBuffer?.name else {
                    return ""
                }
        
        return """
                function (data) {
                     if (data.hasOwnProperty(\"\(visibilityLabel)\")) {
                     var x = data[\"\(visibilityLabel)\"][\"data\"][data[\"\(visibilityLabel)\"][\"data\"].length-1];
                     var imageElement = document.getElementById(\"element\(id)\");
                     if (x <= 0.0 || x.length == 0) {
                         imageElement.style.display = \"none\";
                     } else {
                         imageElement.style.display = \"block\";
                     }
                }
            """
    }
    
}
