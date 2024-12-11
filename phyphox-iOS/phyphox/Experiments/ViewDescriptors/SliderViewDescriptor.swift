//
//  SliderViewDescriptor.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 26.11.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation


struct SliderViewDescriptor: ViewDescriptor, Equatable {
    var label: String
    
    let minValue: Double?
    let maxValue: Double?
    let stepSize: Double?
    let defaultValue: Double?
    let precision: Int
    
    let buffer: DataBuffer
    
    var value: Double {
        return buffer.last ?? (defaultValue ?? 0.0)
    }
    
    var translation: ExperimentTranslationCollection?
    
    init(label: String, minValue: Double?, maxValue: Double?, stepSize: Double?, defaultValue: Double?, precision: Int, buffer: DataBuffer, translation: ExperimentTranslationCollection? = nil) {
        self.label = label
        self.minValue = minValue
        self.maxValue = maxValue
        self.stepSize = stepSize
        self.defaultValue = defaultValue
        self.precision = precision
        self.buffer = buffer
        self.translation = translation
    }
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        return "<div style=\"font-size: 105%;\" class=\"sliderElement\" id=\"element\(id)\"><span class=\"label\">\(localizedLabel)</span><span class=\"value\" id=\"value\(id)\">\(defaultValue ?? 0.0)</span><br><input type=\"range\" class=\"slider\" id=\"input\(id)\" min=\"1\" max=\"100\" value=\"100\" onclick=\"ajax('control?cmd=trigger&element=\(id)');\"> </select></div>"
    }
    
    func setDataHTMLWithID(_ id: Int) -> String {
        let bufferName = buffer.name
        
        return """
            
            function (data) {
                    if (!data.hasOwnProperty("\(bufferName)"))
                        return;
                    var x = data["\(bufferName)"]["data"][data["\(bufferName)"]["data"].length - 1];
                    var selectedValue = parseFloat(x)
                    var sliderElement = document.getElementById("input\(id)")
            
                    var valueDisplay = document.getElementById("valueDisplay\(id)");
            
                    if (sliderElement) {
                        sliderElement.min = \(minValue ?? 0.0);
                        sliderElement.max = \(maxValue ?? 1.0);
                        sliderElement.value = x || \(defaultValue ?? 0.0); 
                    }
                    if (valueDisplay) {
                        valueDisplay.textContent = x.toFixed(1) || \(defaultValue ?? 0.0);
                    }
            
            }

            """
    }
    
    
}
