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
        //The resource name is a query value of /res (decoded by the web server before the resource lookup)
        let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let encodedSrc = src.addingPercentEncoding(withAllowedCharacters: unreserved) ?? src
        return "<div class=\"imageElement\" id=\"element\(id)\"><img style=\"width: \(scale*100.0)%\" class=\"lightFilter_\(lightFilter.rawValue) darkFilter_\(darkFilter.rawValue)\" src=\"res?src=\(encodedSrc)\"></div>"
    }
    
}
