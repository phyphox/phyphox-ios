//
//  DropdownViewDescriptor.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 24.10.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

struct DropdownViewMap: Equatable {
    let value: Double
    let replacement: String?
}

struct DropdownViewDescriptor: ViewDescriptor, Equatable {
    var label: String
    let defaultValue: Double
    let buffer: DataBuffer
    var mappings: [DropdownViewMap]
    
    var value: Double {
        return buffer.last ?? defaultValue
    }
    
    var translation: ExperimentTranslationCollection?
    
    init(label: String, defaultValue: Double, buffer: DataBuffer, mappings: [DropdownViewMap], translation: ExperimentTranslationCollection? = nil) {
        self.label = label
        self.defaultValue = defaultValue
        self.buffer = buffer
        self.mappings = mappings
        self.translation = translation
    }
    
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        return "<div style=\"font-size: 105%;\" class=\"dropdownElement\" id=\"element\(id)\"><span class=\"label\">\(localizedLabel)</span><select onchange=\"ajax('control?cmd=set&buffer=\(buffer.name)&value='+this.value)\" class=\"value\" id=\"select\(id)\" /></div>"
    }
    
    func setDataHTMLWithID(_ id: Int) -> String {
        
        let bufferName = buffer.name
        let options = mappings.map{ $0.replacement ?? "" }
        let values = mappings.map { Double($0.value) ?? 0.0 }
        
        return """
            
            function (data) {
                    if (!data.hasOwnProperty("\(bufferName)"))
                        return;
                    var x = data["\(bufferName)"]["data"][data["\(bufferName)"]["data"].length - 1];
                    
                    var dropdownElement = document.getElementById("select\(id)")
            
                    var selectedValue = x
                    dropdownElement.innerHTML = ""
            
                    var values = \(values)
                    var options = \(options) // .map(value => parseFloat(value).toFixed(1));
                    for (var i = 0; i < options.length ; i++){
                        var option = document.createElement("option")
                        option.value = values[i]
                        if(options[i] == ""){
                            option.text = values[i]
                        } else {
                            option.text = options[i]
                        }
                        
                        dropdownElement.appendChild(option)
                    }
            
            
                    if (values.includes(selectedValue)) {
                        dropdownElement.selectedIndex = values.indexOf(selectedValue)
                    } else {
                      dropdownElement.selectedIndex = 0
                    }
            
             
            }

            """
    }
    
    
}
