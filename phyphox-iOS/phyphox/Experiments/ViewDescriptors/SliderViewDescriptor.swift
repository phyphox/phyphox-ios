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
    let type: SliderType
    var outputBuffers: [DataBuffer]? = nil
    var buffer: DataBuffer? = nil
    
    var value: Double {
        return buffer?.last ?? (defaultValue ?? 0.0)
    }
      
    
    var translation: ExperimentTranslationCollection?
    
    init(label: String, minValue: Double?, maxValue: Double?, stepSize: Double?, defaultValue: Double?, precision: Int, buffer: DataBuffer?, outputBuffers: [DataBuffer]?, translation: ExperimentTranslationCollection? = nil, type: SliderType) {
        self.label = label
        self.minValue = minValue
        self.maxValue = maxValue
        self.stepSize = stepSize
        self.defaultValue = defaultValue
        self.precision = precision
        self.buffer = buffer
        self.translation = translation
        self.type = type
        self.outputBuffers = outputBuffers
    }
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        var stepSize_ = 1.0
        let precisionValue = Double(self.precision)
        if(self.stepSize == 0){
            stepSize_ = Double(1 / pow(10, precisionValue))
        } else {
            stepSize_ = self.stepSize ?? 1
        }
        
        let minValueFormatted = numberFormatter(for: minValue ?? 0.0)
        let maxValueFormatted = numberFormatter(for: maxValue ?? 1.0)
        let defaultValueFormatted = numberFormatter(for: defaultValue ?? 0.0)
        
        
        return "<div style=\"font-size: 105%;\" class=\"sliderElement\" id=\"element\(id)\"><span class=\"label\">\(localizedLabel)</span><span class=\"value\" id=\"value\(id)\">\(defaultValueFormatted)</span><div class=\"sliderContainer\"><span class=\"minValue\" id=\"minValue\(id)\">\(minValueFormatted)</span><input type=\"range\" class=\"slider\" id=\"input\(id)\" min=\"1\" max=\"100\" value=\"100\" step=\(stepSize_) onchange=\"ajax('control?cmd=set&buffer=\(buffer?.name ?? "")&value='+this.value)\" ></input><span class=\"maxValue\" id=\"maxValue\(id)\">\(minValueFormatted)</span></div></div>"
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
        
        let bufferName = buffer?.name ?? ""
        let minValueFormatted = numberFormatter(for: minValue ?? 0.0)
        let maxValueFormatted = numberFormatter(for: maxValue ?? 1.0)
        let defaultValueFormatted = numberFormatter(for: defaultValue ?? 0.0)
        
        
        return """
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
                       x = parseFloat(sliderElement.value.toFixed(\(self.precision)))
                       data["\(bufferName)"]["data"][data["\(bufferName)"]["data"].length - 1] = x
                   });
                   
                }
            }

            """
    }
    
    
}


/**
 
 
 
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
       x = parseFloat(sliderElement.value.toFixed(\(self.precision)))
       data["\(bufferName)"]["data"][data["\(bufferName)"]["data"].length - 1] = x
   });
   
}
 
 */


/**
 
 return "<div style=\"font-size: 105%;\" class=\"sliderElement\" id=\"element\(id)\"><span class=\"label\">\(localizedLabel)</span><span class=\"value\" id=\"value\(id)\">\(defaultValueFormatted)</span><div class=\"sliderContainer\"><span class=\"minValue\" id=\"minValue\(id)\">\(minValueFormatted)</span><section class =\"range-slider\"><span class =\"rangeValues\"></span><input type=\"range\" class=\"slider\" id=\"input\(id)\" min=\"1\" max=\"100\" value=\"20\" step=\"0.5\" onchange=\"ajax('control?cmd=set&buffer=\(buffer?.name ?? "")&value='+this.value)\"><input value=\"50\" min=\"0\" max=\"100\" step=\"0.5\" type=\"range\"></section><span class=\"maxValue\" id=\"maxValue\(id)\">\(maxValueFormatted)</span></div></div>"
 
 var lowerBufferName: String? = nil
 var upperBufferName: String? = nil
 var bufferName: String? = nil
 if(type == SliderType.Range){
     let bufferNames = outputBuffers?.map{ $0.name}
     lowerBufferName = bufferNames?[0]
     upperBufferName = bufferNames?[1]
 }
 
 if(type == SliderType.Normal){
     bufferName = buffer?.name
 }
 
 
 function (data) {
         
         if("\(type)" == "\(SliderType.Range)"){
 
                     if (!data.hasOwnProperty("\(lowerBufferName ?? "")"))
                            return;
                     if (!data.hasOwnProperty("\(upperBufferName ?? "")"))
                             return;
                     var x = data["\(lowerBufferName ?? "")"]["data"][data["\(lowerBufferName ?? "")"]["data"].length - 1];
                     var y = data["\(upperBufferName ?? "")"]["data"][data["\(upperBufferName ?? "")"]["data"].length - 1];
                     var lowerValue = parseFloat(x)
                     var upperValue = parseFloat(y)
             
                                     console.log(lowerValue)
                                     console.log(upperValue)
 
                         
 
                     // Range slider code is taken from https://stackoverflow.com/questions/4753946/html-slider-with-two-inputs-possible
                     var slides = document.getElementsByTagName("input");
                     var slide1 = parseFloat(slides[1].value);
                     var slide2 = parseFloat(slides[2].value);
 
                                                     slides[1].value = lowerValue
                                                     slides[2].value = upperValue
                     
                     if( slide1 > slide2 ){ var tmp = slide2; slide2 = slide1; slide1 = tmp; }
             
                     var valueDisplay = document.getElementById("value\(id)");
             
                     if (valueDisplay) {
                         valueDisplay.textContent = slide1 + " - " + slide2;
                        
                     }
 
 if (slides[1]){
     slides[1].addEventListener('input', function () {
        if (valueDisplay) {
            valueDisplay.textContent = parseFloat(slides[1].value).toFixed(\(self.precision));
        }
        x = parseFloat(slides[1].value.toFixed(\(self.precision)))
                                        data["\(lowerBufferName ?? "")"]["data"][data["\(lowerBufferName ?? "")"]["data"].length - 1] = x
    });
    
 }
 
             if (slides[2]){
                 slides[2].addEventListener('input', function () {
                    if (valueDisplay) {
                        valueDisplay.textContent = parseFloat(slides[2].value).toFixed(\(self.precision));
                    }
                    x = parseFloat(slides[2].value.toFixed(\(self.precision)))
                    data["\(upperBufferName ?? "")"]["data"][data["\(upperBufferName ?? "")"]["data"].length - 1] = x
                });
                
             }
             
                     var sliderSections = document.getElementsByClassName("range-slider");
                         for( var x = 0; x < sliderSections.length; x++ ){
                             var sliders = sliderSections[x].getElementsByTagName("input");
                             for( var y = 0; y < sliders.length; y++ ){
                                 if( sliders[y].type ==="range" ){
                                     // sliders[y].oninput = slide1;
                                     // Manually trigger event first time to display values
                                     // sliders[y].oninput();
                                 }
                             }
                         }
 
         }
         
 }
 
 
 */
