//
//  ImageViewElementHandler.swift
//  phyphox
//
//  Created by Sebastian Staacks on 08.05.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

struct ImageViewElementDescriptor {
    let src: String
    let scale: CGFloat
    
    let darkFilter: Filter
    let lightFilter: Filter
    
    enum Filter: String, LosslessStringConvertible {
        case none, invert
    }
}

final class ImageViewElementHandler: ResultElementHandler, ChildlessElementHandler, ViewComponentElementHandler {
    var results = [ViewElementDescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case scale
        case src
        case darkFilter
        case lightFilter
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let scale: CGFloat = try attributes.optionalValue(for: .scale) ?? 1.0

        let src = try attributes.string(for: .src)
        
        let darkFilter: ImageViewElementDescriptor.Filter = try attributes.optionalValue(for: .darkFilter) ?? .none
        
        let lightFilter: ImageViewElementDescriptor.Filter = try attributes.optionalValue(for: .lightFilter) ?? .none

        results.append(.image(ImageViewElementDescriptor(src: src, scale: scale, darkFilter: darkFilter, lightFilter: lightFilter)))
    }

    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}
