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

        return "<div style=\"font-size: 105%;\" class=\"sliderElement\" id=\"element\(id)\"><span class=\"label\">\(localizedLabel)</span><span class=\"value\" id=\"value\(id)\">\(defaultValue ?? 0.0)</span><div class=\"sliderContainer\"><span class=\"minValue\" id=\"minValue\(id)\">\(minValue ?? 0.0)</span><input type=\"range\" class=\"slider\" id=\"input\(id)\" min=\"1\" max=\"100\" value=\"100\" onchange=\"ajax('control?cmd=set&buffer=\(buffer.name)&value='+this.value)\" ></input><span class=\"maxValue\" id=\"maxValue\(id)\">\(maxValue ?? 0.0)</span></div></div>"
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
            
                    var valueDisplay = document.getElementById("value\(id)");
            
                    if (sliderElement) {
                        sliderElement.min = \(minValue ?? 0.0);
                        sliderElement.max = \(maxValue ?? 1.0);
                        sliderElement.value = x || \(defaultValue ?? 0.0); 
                    }
                    if (valueDisplay) {
                        if(x.toFixed(1) == 0.0){
                            valueDisplay.textContent = \(defaultValue ?? 0.0);
                        } else {
                            valueDisplay.textContent = x.toFixed(1)
                        }
                        
                    }
            
                    if (sliderElement){
                        sliderElement.addEventListener('input', function () {
                            if (valueDisplay) {
                                valueDisplay.textContent = parseFloat(sliderElement.value).toFixed(1);
                            }
                            x = parseFloat(sliderElement.value)
                            data["\(bufferName)"]["data"][data["\(bufferName)"]["data"].length - 1] = x
                        });
                        
            }
            }

            """
    }
    
    
}
