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
    var minValue: Double
    var maxValue: Double
    var stepSize: Double
    var defaultValue: Double?
    let outputBufferName: String?
    let lowerBufferName: String
    let upperBufferName: String
    let outputBufferNames: [String]?
    let precision: Int
    let type: SliderType
    let showValue: Bool
}

enum SliderType: String {
    case Normal
    case Range
}

private struct RangeSliderOutputDescriptor {
    let value: String
    let bufferName: String
}

private final class RangeSliderOutputElementHandler: ResultElementHandler, ChildlessElementHandler, AttributelessElementHandler {
    var results = [RangeSliderOutputDescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case value
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        guard !text.isEmpty else {
            throw ElementHandlerError.missingText
        }

        let attributes = attributes.attributes(keyedBy: Attribute.self)
        
        let value = try attributes.optionalValue(for: .value) ?? ""
     
        results.append(RangeSliderOutputDescriptor(value: value, bufferName: text))
    }
}

final class SliderViewElementHandler: ResultElementHandler, LookupElementHandler, ViewComponentElementHandler {
    var results = [ViewElementDescriptor]()
    
    var childHandlers: [String : ElementHandler]
    //var rangeSliderChildHandlers: [String : ElementHandler]
    
    private let outputHandler = TextElementHandler()
    
    private let rangeSliderOutputHandler = RangeSliderOutputElementHandler()
    
    init() {

        childHandlers = ["output": rangeSliderOutputHandler]
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
        
        let outputBufferName = (sliderType == .Normal) ? rangeSliderOutputHandler.results.first?.bufferName : nil
        
        var outputBufferNames_: [String] = []
        var lowerBufferName = ""
        var upperBufferName = ""
        
        if(sliderType == .Range) {
            let outputBuffers = rangeSliderOutputHandler.results
            guard outputBuffers.count > 0 else {
                throw ElementHandlerError.missingElement("output")
            }
            
            for outputBuffer in outputBuffers {
                let value = outputBuffer.value
                if(value == "lowerValue"){
                    lowerBufferName = outputBuffer.bufferName
                }
                
                if(value == "upperValue"){
                    upperBufferName = outputBuffer.bufferName
                }
                outputBufferNames_.append(value)
                
            }
        }
        
        results.append(.slider(SliderViewElementDescriptor(
            label: label,
            minValue: minValue,
            maxValue: maxValue,
            stepSize: stepSize,
            defaultValue: defaultValue,
            outputBufferName: outputBufferName,
            lowerBufferName: lowerBufferName ,
            upperBufferName: upperBufferName,
            outputBufferNames : outputBufferNames_,
            precision: precision,
            type: sliderType,
            showValue: showValue)))
    }
}
