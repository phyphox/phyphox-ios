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
    
    init(label: String, minValue: Double, maxValue: Double, stepSize: Double, defaultValue: Double, precision: Int, outputBuffers: [SliderOutputValueType: DataBuffer], translation: ExperimentTranslationCollection?, type: SliderType, showValue: Bool) {
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
    
    func getStepSize() -> Double {
        let precisionValue = Double(self.precision)
        if(self.stepSize == 0){
            return Double(1 / pow(10, precisionValue))
        } else {
            return self.stepSize
        }
    }
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        
        let minValueFormatted = numberFormatter(for: minValue)
        let maxValueFormatted = numberFormatter(for: maxValue)
        let defaultValueFormatted = numberFormatter(for: defaultValue ?? 0.0)
        
        let bufferName = outputBuffers[.Empty]?.name ?? ""
        
        let valueTag = showValue ? "<span class=\"label\">\(localizedLabel)</span><span class=\"value\" id=\"value\(id)\">\(defaultValueFormatted)</span>" : ""
        
        return (type == SliderType.Range) ? generateTwoSlidersHTML(id) :
        
        "<div style=\"font-size: 105%;\" class=\"sliderElement\" id=\"element\(id)\">\(valueTag)<div class=\"sliderContainer\"><span class=\"minValue\" id=\"minValue\(id)\">\(minValueFormatted)</span><input type=\"range\" class=\"slider\" id=\"input\(id)\" min=\"1\" max=\"100\" value=\"100\" step=\(getStepSize())></input><span class=\"maxValue\" id=\"maxValue\(id)\">\(maxValueFormatted)</span></div></div>"
    }
    
    private func generateTwoSlidersHTML(_ id: Int) -> String{
        let minValueFormatted = numberFormatter(for: minValue)
        let maxValueFormatted = numberFormatter(for: maxValue)
        let defaultValueFormatted = numberFormatter(for: defaultValue ?? 0.0)
        
        let valueTag = showValue ? "<span class=\"label\">\(localizedLabel)</span>" +
        "<span class=\"value\" id=\"value\(id)\">\(defaultValueFormatted)</span>" : ""
        
        return "<div style=\"font-size: 105%;\" class=\"sliderElement\" id=\"element\(id)\">" + valueTag +
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
                var selectedValue = parseFloat(x).toFixed("+precision+")
                var sliderElement = document.getElementById("input\(id)")
                           
                var valueDisplay = document.getElementById("value\(id)");

                if (sliderElement) {
                   sliderElement.min = \(minValueFormatted);
                   sliderElement.max = \(maxValueFormatted);
                   sliderElement.step = \(getStepSize());
                }
                
                if (!sliderElement.classList.contains(\"isSliderUpdating\")) {
                    sliderElement.value = selectedValue || \(defaultValueFormatted) ;
                }
            
                if(valueDisplay){
                    valueDisplay.textContent = parseFloat(sliderElement.value).toFixed(\(self.precision));
                }
            
                sliderElement.addEventListener('input', function() {
                    if (!sliderElement.classList.contains(\"isSliderUpdating\")) {
                        sliderElement.classList.add(\"isSliderUpdating\");
                     }
               });

                sliderElement.addEventListener('change', function() {
                     if (valueDisplay) {
                        valueDisplay.textContent = parseFloat(sliderElement.value).toFixed(\(self.precision));
                     }
                     if (sliderElement.classList.contains(\"isSliderUpdating\")) {
                        ajax('control?cmd=set&buffer=\(bufferName)&value='+sliderElement.value)
                        sliderElement.classList.remove(\"isSliderUpdating\");
                     }
                });

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
                            } else { return; }
            
                             if (!sliderElementOne.classList.contains(\"isSliderOneUpdating\")) {
                                 sliderElementOne.value = selectedValueX;
                              }
                            if (!sliderElementTwo.classList.contains(\"isSliderTwoUpdating\")) {
                                 sliderElementTwo.value = selectedValueY;
                            }

                            if(valueDisplay){
                                valueDisplay.textContent = parseFloat(sliderElementOne.value).toFixed(\(precision)).concat(\" - \", parseFloat(sliderElementTwo.value).toFixed(\(precision)))
                            }
            
                            sliderElementOne.addEventListener('input', function() {
                                if (!sliderElementOne.classList.contains(\"isSliderOneUpdating\")) {
                                    sliderElementOne.classList.add(\"isSliderOneUpdating\")
                                }
                                if(Number(sliderElementOne.value) > Number(sliderElementTwo.value)) {
                                    sliderElementOne.value = sliderElementTwo.value
                                    }
                             });

                             sliderElementOne.addEventListener('change', function() {
                                if(Number(sliderElementOne.value) <= Number(sliderElementTwo.value)) {
                                    if (valueDisplay) {
                                        valueDisplay.textContent = parseFloat(sliderElementOne.value).toFixed(\(precision)).concat(\" - \", parseFloat(sliderElementTwo.value).toFixed(\(precision)))
                                    }
                                if (sliderElementOne.classList.contains(\"isSliderOneUpdating\")) {
                                    ajax('control?cmd=set&buffer=\(lowerValueBufferName)&value='+sliderElementOne.value)
                                    sliderElementOne.classList.remove(\"isSliderOneUpdating\")
                                    }
                                }
                              });

                              sliderElementTwo.addEventListener('input', function() {
                                 if (!sliderElementTwo.classList.contains(\"isSliderTwoUpdating\")) {
                                    sliderElementTwo.classList.add(\"isSliderTwoUpdating\")
                                }
                                if(Number(sliderElementOne.value) > Number(sliderElementTwo.value)) {
                                    sliderElementTwo.value = sliderElementOne.value
                                }
                              });

                               sliderElementTwo.addEventListener('change', function() {
                                    if(Number(sliderElementOne.value) <= Number(sliderElementTwo.value)) {
                                        if (valueDisplay) {
                                            valueDisplay.textContent = parseFloat(sliderElementOne.value).toFixed(\(precision)).concat(\" - \", parseFloat(sliderElementTwo.value).toFixed(\(precision)))
                                        }
                                        if (sliderElementTwo.classList.contains(\"isSliderTwoUpdating\")) {
                                            ajax('control?cmd=set&buffer=\(upperValueBufferName)&value='+sliderElementTwo.value)
                                            sliderElementTwo.classList.remove(\"isSliderTwoUpdating\")
                                        }
                                    }
                               });
                }
            """
    }
    
    
}
