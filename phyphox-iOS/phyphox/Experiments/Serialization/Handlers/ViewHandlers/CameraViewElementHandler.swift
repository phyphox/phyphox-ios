//
//  CameraViewElementHandler.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 07.09.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation

struct CameraViewElementDescriptor {
    let label: String
    let exposureAdjustmentLevel: String
    let aspectRatio: CGFloat
    let grayscale: String
    let markOverexposure: String
    let markUnderexposure: String
}

final class CameraViewElementHandler: ResultElementHandler, ChildlessElementHandler, ViewComponentElementHandler {
    var results = [ViewElementDescriptor]()
    
    func startElement(attributes: AttributeContainer) throws {}
    
    private enum Attribute: String, AttributeKey {
        case label
        case aspectRatio
        case exposure_adjustment_level
        case grayscale
        case markOverexposure
        case markUnderexposure
    }
    
    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)
        
        let label = attributes.optionalString(for: .label) ?? ""
        
        let exposureAdjustmentLevel = attributes.optionalString(for: .exposure_adjustment_level) ?? ""
        
        let aspectRatio: CGFloat = try attributes.optionalValue(for: .aspectRatio) ?? 2.5
        
        let grayScale = attributes.optionalString(for: .grayscale) ?? ""
        
        let markOverexposure = attributes.optionalString(for: .markOverexposure) ?? ""
        
        let markUnderexposure = attributes.optionalString(for: .markUnderexposure) ?? ""
        
        results.append(.camera(CameraViewElementDescriptor(label: label, exposureAdjustmentLevel: exposureAdjustmentLevel, aspectRatio: aspectRatio, grayscale: grayScale, markOverexposure: markOverexposure, markUnderexposure: markUnderexposure)))
    }
    
    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}
