//
//  SliderViewDescriptor.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 26.11.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

enum SliderOutputValueType {
    case LowerValue
    case UpperValue
    case Empty
}


struct SliderViewDescriptor: ViewDescriptor, Equatable {
    var label: String
    
    let minValue: Double
    let maxValue: Double
    let stepSize: Double
    let defaultValue: Double
    let precision: Int
    let type: SliderType
    var outputBuffers: [SliderOutputValueType: DataBuffer]
    
    let showValue: Bool
    
    var translation: ExperimentTranslationCollection?
    
    init(label: String, minValue: Double, maxValue: Double, stepSize: Double, defaultValue: Double, precision: Int, outputBuffers: [SliderOutputValueType: DataBuffer], translation: ExperimentTranslationCollection? = nil, type: SliderType, showValue: Bool) {
        self.label = label
        self.minValue = minValue
        self.maxValue = maxValue
        self.stepSize = stepSize
        self.defaultValue = defaultValue
        self.precision = precision
        self.translation = translation
        self.type = type
        self.outputBuffers = outputBuffers
        self.showValue = showValue
    }
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        var stepSize_ = 1.0
        let precisionValue = Double(self.precision)
        if(self.stepSize == 0){
            stepSize_ = Double(1 / pow(10, precisionValue))
        } else {
            stepSize_ = self.stepSize
        }
        
        let minValueFormatted = numberFormatter(for: minValue)
        let maxValueFormatted = numberFormatter(for: maxValue)
        let defaultValueFormatted = numberFormatter(for: defaultValue ?? 0.0)
        
        let bufferName = outputBuffers[.Empty]?.name ?? ""
        
        return (type == SliderType.Range) ? generateTwoSlidersHTML(id) :
        
        "<div style=\"font-size: 105%;\" class=\"sliderElement\" id=\"element\(id)\"><span class=\"label\">\(localizedLabel)</span><span class=\"value\" id=\"value\(id)\">\(defaultValueFormatted)</span><div class=\"sliderContainer\"><span class=\"minValue\" id=\"minValue\(id)\">\(minValueFormatted)</span><input type=\"range\" class=\"slider\" id=\"input\(id)\" min=\"1\" max=\"100\" value=\"100\" step=\(stepSize_) onchange=\"ajax('control?cmd=set&buffer=\(bufferName)&value='+this.value)\" ></input><span class=\"maxValue\" id=\"maxValue\(id)\">\(maxValueFormatted)</span></div></div>"
    }
    
    private func generateTwoSlidersHTML(_ id: Int) -> String{
        let minValueFormatted = numberFormatter(for: minValue)
        let maxValueFormatted = numberFormatter(for: maxValue)
        let defaultValueFormatted = numberFormatter(for: defaultValue ?? 0.0)
        
        return "<div style=\"font-size: 105%;\" class=\"sliderElement\" id=\"element\(id)\">" +
                                                    "<span class=\"label\">\(localizedLabel)</span>" +
                                                    "<span class=\"value\" id=\"value\(id)\">\(defaultValueFormatted)</span>" +
                                                    "<div class=\"sliderContainer\">" +
                                                    "<span class=\"minValue\" >\(minValueFormatted)</span>" +
                                                        "<input type=\"range\" class=\"slider\" id=\"input\(id)\"" +
                                                            "min=\"1\" max=\"100\" value=\"100\" step=\(stepSize)\"" +
                                                            ">" +
                                                        "</input>" +
                                                    "<span class=\"maxValue\"></span>" +
                                                    "</div>" +
                                                    "<div class=\"sliderContainer\">" +
                                                    "<span class=\"minValue\"></span>" +
                                                    "<input type=\"range\" class=\"slider\" id=\"input11\(id)\"" +
                                                            "min=\"1\" max=\"100\" value=\"100\" step=\(stepSize)\"" +
                                                            ">" +
                                                            "</input>" +
                                                        "<span class=\"maxValue\">\(maxValueFormatted)</span>" +
                                                    "</div>" +
                                            "</div>";
    }
    
    func numberFormatter(for value: Double) -> String{
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = self.precision
        formatter.maximumFractionDigits = self.precision
        formatter.minimumIntegerDigits = 1
        formatter.numberStyle = .decimal
        
        let number = NSNumber(value: value)
        
        return formatter.string(from: number) ?? " "
        
    }
    
    func setDataHTMLWithID(_ id: Int) -> String {
        
        let bufferName = outputBuffers[.Empty]?.name ?? ""
        let minValueFormatted = numberFormatter(for: minValue)
        let maxValueFormatted = numberFormatter(for: maxValue)
        let defaultValueFormatted = numberFormatter(for: defaultValue ?? 0.0)

        return (type == SliderType.Range) ? setDataHTMLWithIDForRangeSlider(id) :
        
        
            """
             function (data) {
                if (!data.hasOwnProperty("\(bufferName)"))
                       return;
                var x = data["\(bufferName)"]["data"][data["\(bufferName)"]["data"].length - 1];
                var selectedValue = parseFloat(x)
                var sliderElement = document.getElementById("input\(id)")
                           
                var valueDisplay = document.getElementById("value\(id)");

                if (sliderElement) {
                   sliderElement.min = \(minValueFormatted);
                   sliderElement.max = \(maxValueFormatted);
                   sliderElement.value = x || \(defaultValueFormatted);
                }
                if (valueDisplay) {
                   if(x.toFixed(1) == 0.0){
                       valueDisplay.textContent = \(defaultValueFormatted);
                   } else {
                       valueDisplay.textContent = x.toFixed(\(self.precision));
                   }
                   
                }

                if (sliderElement){
                   sliderElement.addEventListener('input', function () {
                       if (valueDisplay) {
                           valueDisplay.textContent = parseFloat(sliderElement.value).toFixed(\(self.precision));
                       }
                       x = parseFloat(parseFloat(sliderElement.value).toFixed(\(self.precision)))
                       data["\(bufferName)"]["data"][data["\(bufferName)"]["data"].length - 1] = x
                   });
                   
                }
            }

            """
    }
    
    private func setDataHTMLWithIDForRangeSlider(_ id: Int) -> String {
        let lowerValueBufferName = outputBuffers[.LowerValue]?.name ?? ""
        let upperValueBufferName = outputBuffers[.UpperValue]?.name ?? ""
        let minValueFormatted = numberFormatter(for: minValue)
        let maxValueFormatted = numberFormatter(for: maxValue)
        let defaultValueFormatted = numberFormatter(for: defaultValue ?? 0.0)
        
        let lowerBuffer = outputBuffers[.LowerValue]?.last ?? 0.0
        let upperBuffer = outputBuffers[.UpperValue]?.last ?? 0.0
        
        return """
                function (data) {
                          if (!data.hasOwnProperty("\(lowerValueBufferName)"))
                                return;
                          if (!data.hasOwnProperty("\(upperValueBufferName)"))
                                return;

                          var x = data["\(lowerValueBufferName)"][\"data\"][data["\(lowerValueBufferName)"][\"data\"].length - 1]
                          var y = data["\(upperValueBufferName)"][\"data\"][data["\(upperValueBufferName)"][\"data\"].length - 1]

                          var selectedValueX = parseFloat(x).toFixed(\(precision))
                          var selectedValueY = parseFloat(y).toFixed(\(precision))

                            var sliderElementOne = document.getElementById(\"input\(id)")
                            var sliderElementTwo = document.getElementById(\"input11\(id)")
                            var valueDisplay = document.getElementById(\"value\(id)")

                            if (sliderElementOne && sliderElementTwo) {
                                sliderElementOne.min = \(minValueFormatted)
                                sliderElementTwo.min = \(minValueFormatted)
                                sliderElementOne.max = \(maxValueFormatted)
                                sliderElementTwo.max = \(maxValueFormatted)
                                sliderElementOne.step = \(stepSize)
                                sliderElementTwo.step = \(stepSize)
                                sliderElementOne.value = selectedValueX || \(defaultValueFormatted)
                                sliderElementTwo.value = selectedValueY || \(defaultValueFormatted)
                            }

                            if(valueDisplay){
                                valueDisplay.textContent = parseFloat(sliderElementOne.value).toFixed(\(precision)).concat(\" - \", parseFloat(sliderElementTwo.value).toFixed(\(precision)))
                            }

                            if (sliderElementOne || sliderElementTwo){
                                sliderElementOne.onchange = function() {
                                    if(sliderElementOne.value <= sliderElementTwo.value) {
                                        if (valueDisplay) {
                                            valueDisplay.textContent = parseFloat(sliderElementOne.value).toFixed(\(precision)).concat(\" - \", parseFloat(sliderElementTwo.value).toFixed(\(precision)))
                                        }
                                        console.log("sliderElementOne")
                                        console.log(parseFloat(sliderElementOne.value).toFixed(\(precision)))
                                        console.log("lowerBuffer")
                                        console.log(\(lowerBuffer))
                                        ajax('control?cmd=set&buffer=\(lowerValueBufferName)&value='+sliderElementOne.value)
                                    }
                                }
            

                                sliderElementTwo.onchange = function() {
                                      if(sliderElementOne.value <= sliderElementTwo.value) {
                                        if (valueDisplay) {
                                              valueDisplay.textContent = parseFloat(sliderElementOne.value).toFixed(\(precision)).concat(\" - \", parseFloat(sliderElementTwo.value).toFixed(\(precision)))
                                              }
                                        
                                        console.log("sliderElementTwo")
                                        console.log(parseFloat(sliderElementTwo.value).toFixed(\(precision)))
                                        console.log("upperBuffer")
                                        console.log(\(upperBuffer))
                                        ajax('control?cmd=set&buffer=\(upperValueBufferName)&value='+sliderElementTwo.value)
                                        }
                                }
                        }
                }
            """
    }
    
    
}
