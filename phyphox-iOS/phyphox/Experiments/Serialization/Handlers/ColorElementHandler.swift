//
//  ColorElementHandler.swift
//  phyphox
//
//  Created by Sebastian Staacks on 19.03.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//


import Foundation

/// Element handler extracting the text content from an element and interpreting it as a color. This can be either a hex value or one of the named colors.
final class ColorElementHandler: ResultElementHandler, AttributelessElementHandler, ChildlessElementHandler {
    
    var results = [UIColor]()
    
    func endElement(text: String, attributes: AttributeContainer) throws {
        guard !text.isEmpty else { throw ElementHandlerError.missingText }
        
        if let color = mapColorString(text) {
            results.append(color)
        } else {
            throw ElementHandlerError.unexpectedAttributeValue("color")
        }
        
    }
    
}
