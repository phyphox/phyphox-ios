//
//  SliderViewElementHandler.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 26.11.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

struct SliderViewElementDescriptor{
    var label: String
    var minValue: Double?
    var maxValue: Double?
    var stepSize: Double?
    var defaultValue: Double?
    let outputBufferName: String
    let precision: Int
}


final class SliderViewElementHandler: ResultElementHandler, LookupElementHandler, ViewComponentElementHandler {
    var results = [ViewElementDescriptor]()
    
    var childHandlers: [String : ElementHandler]
    
    private let outputHandler = TextElementHandler()
    
    init() {
        childHandlers = ["output": outputHandler]
    }
    
    private enum Attribute: String, AttributeKey {
        case label
        case minValue
        case maxValue
        case stepSize
        case defaultValue
        case precision
    }
    
    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else {
            throw ElementHandlerError.missingElement("")
        }
        return results.removeFirst()
    }
    
    func startElement(attributes: AttributeContainer) throws {}
    
    func endElement(text: String, attributes: AttributeContainer) throws {
        
        let attributes = attributes.attributes(keyedBy: Attribute.self)
        
        let label = attributes.optionalString(for: .label) ?? ""
        let minValue = try attributes.optionalValue(for: .minValue) ?? 0.0
        let maxValue = try attributes.optionalValue(for: .maxValue) ?? 1.0
        let stepSize = try attributes.optionalValue(for: .stepSize) ?? 1.0
        let defaultValue = try attributes.optionalValue(for: .defaultValue) ?? 0.0
        let precision = try attributes.optionalValue(for: .precision) ?? 2
        
        let outputBufferName = try outputHandler.expectSingleResult()
        
        results.append(.slider(SliderViewElementDescriptor(label: label, minValue: minValue, maxValue: maxValue, stepSize: stepSize, defaultValue: defaultValue, outputBufferName: outputBufferName, precision: precision)))
        
    }
    
    
}
