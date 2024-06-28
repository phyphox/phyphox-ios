//
//  ImageViewElementHandler.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 27.06.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

struct ImageViewElementDescriptor {
    let src: String
    let scale: Double
    let lightFilter: String
    let darkFilter: String
}

final class ImageViewElementHandler: ResultElementHandler, ChildlessElementHandler, ViewComponentElementHandler {
    
    var results = [ViewElementDescriptor]()
    
    func startElement(attributes: AttributeContainer) throws {}
    
    private enum Attribute: String, AttributeKey {
        case src
        case scale
        case lightFilter
        case darkFilter
    }
    
    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)
        
        let src = attributes.optionalString(for: .src) ?? ""
        let scale = try attributes.optionalValue(for: .scale) ?? 1.0
        let lightFilter = attributes.optionalString(for: .lightFilter) ?? ""
        let darkFilter = attributes.optionalString(for: .darkFilter) ?? ""
        
        results.append(.image(ImageViewElementDescriptor(src: src, scale: scale, lightFilter: lightFilter, darkFilter: darkFilter)))
    }
    
    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw
            ElementHandlerError.missingElement("") }
        return results.removeFirst()
            
        }
}
