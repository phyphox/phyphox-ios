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
    let lightSrc: String?
    let darkSrc: String?
    let scale: CGFloat
    
    let lightFilter: ImageViewElementDescriptor.Filter
    let darkFilter: ImageViewElementDescriptor.Filter
    
    init(visibilityBuffer: DataBuffer?, src: String, lightSrc: String? = nil, darkSrc: String? = nil, scale: CGFloat, darkFilter: ImageViewElementDescriptor.Filter, lightFilter: ImageViewElementDescriptor.Filter) {
        self.visibilityBuffer = visibilityBuffer
        self.src = src
        self.lightSrc = (lightSrc?.isEmpty ?? true) ? nil : lightSrc
        self.darkSrc = (darkSrc?.isEmpty ?? true) ? nil : darkSrc
        self.scale = scale
        self.darkFilter = darkFilter
        self.lightFilter = lightFilter
        //Every named file is a resource: copied on save, written into a saved state, served by /res
        var resources = [String]()
        for name in [src, self.lightSrc, self.darkSrc].compactMap({ $0 }) where !name.isEmpty && !resources.contains(name) {
            resources.append(name)
        }
        self.resources = resources
    }

    ///The file shown in the given interface mode: lightSrc or darkSrc if given, else src (rule image-mode-src)
    func src(dark: Bool) -> String {
        return (dark ? darkSrc : lightSrc) ?? src
    }
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        //The resource name is a query value of /res (decoded by the web server before the resource lookup)
        let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        func resURL(_ name: String) -> String {
            return "res?src=" + (name.addingPercentEncoding(withAllowedCharacters: unreserved) ?? name)
        }
        //With a file per mode, the web interface picks one by its own bright mode (webinterface readme, "Image elements")
        let modes = (lightSrc != nil || darkSrc != nil) ? " data-light-src=\"\(resURL(src(dark: false)))\" data-dark-src=\"\(resURL(src(dark: true)))\"" : ""
        return "<div class=\"imageElement\" id=\"element\(id)\"><img style=\"width: \(scale*100.0)%\" class=\"lightFilter_\(lightFilter.rawValue) darkFilter_\(darkFilter.rawValue)\" src=\"\(resURL(src))\"\(modes)></div>"
    }
    
}
