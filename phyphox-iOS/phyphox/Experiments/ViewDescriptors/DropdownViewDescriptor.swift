//
//  DropdownViewDescriptor.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 24.10.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

struct DropdownViewMap: Equatable {
    let value: String
    let replacement: String
}

struct DropdownViewDescriptor: ViewDescriptor, Equatable {
    var label: String
    let defaultValue: String?
    let buffer: DataBuffer
    let mappings: [DropdownViewMap]
    
    var value: Double {
        return buffer.last ?? 0.0
    }
    
    var translation: ExperimentTranslationCollection?
    
    init(label: String, defaultValue: String?, buffer: DataBuffer, mappings: [DropdownViewMap], translation: ExperimentTranslationCollection? = nil) {
        self.label = label
        self.defaultValue = defaultValue
        self.buffer = buffer
        self.mappings = mappings
        self.translation = translation
    }
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        return "<div style=\"font-size: 105%;\" class=\"dropdownElement\" id=\"element\(id)\"><span class=\"label\">\(localizedLabel)</span><select class=\"value\" id=\"select\(id)\" onclick=\"ajax('control?cmd=trigger&element=\(id)');\"> </select></div>"
    }
    
    func setDataHTMLWithID(_ id: Int) -> String {
        
        let bufferName = buffer.name
        let options = mappings.map{ $0.replacement}
        
        return """
            
            function (data) {
                    if (!data.hasOwnProperty("\(bufferName)"))
                        return;
                    var x = data["\(bufferName)"]["data"][data["\(bufferName)"]["data"].length - 1];
                    
                    var dropdownElement = document.getElementById("select\(id)")
            
                    var selectedValue = parseFloat(x).toFixed(1)
                    console.log(selectedValue)
                    dropdownElement.innerHTML = ""
            
                    var options = \(options).map(value => parseFloat(value).toFixed(1));
                    console.log(options)
                    for (var i = 0; i < options.length ; i++){
                        var option = document.createElement("option")
                        option.value = options[i]
                        option.text = options[i]
                        dropdownElement.appendChild(option)
                    }
            
                    if (options.includes(selectedValue)) {
                        console.log(options.indexOf(selectedValue))
                        dropdownElement.selectedIndex = options.indexOf(selectedValue)
                    } else {
                       dropdownElement.selectedIndex = 0
                    }
             
            }

            """
    }
    
    
}
