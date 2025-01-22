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
    let outputBufferName: String?
    let outputBufferNames: [String]?
    let precision: Int
    let type: SliderType
    let showValue: Bool
}

enum SliderType: String {
    case Normal
    case Range
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
        case type
        case showValue
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
        let type = attributes.optionalString(for: .type) ?? "normal"
        let showValue = try attributes.optionalValue(for: .showValue) ?? true
        
        let sliderType = (type == "normal") ? SliderType.Normal : SliderType.Range
        
        let outputBufferName = (sliderType == .Normal) ? try outputHandler.expectSingleResult() : nil
        let outputBufferNames = (sliderType == .Range) ? outputHandler.results : nil
        
       
        
        results.append(.slider(SliderViewElementDescriptor(
            label: label,
            minValue: minValue,
            maxValue: maxValue,
            stepSize: stepSize,
            defaultValue: defaultValue,
            outputBufferName: outputBufferName,
            outputBufferNames: outputBufferNames,
            precision: precision,
            type: sliderType,
            showValue: showValue)))
    }
}
