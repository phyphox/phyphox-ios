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
    var visibilityBuffer: DataBuffer?
    let defaultValue: Double
    let buffer: DataBuffer
    var mappings: [DropdownViewMap]
    
    var localizedMappings: [DropdownViewMap] {
        get {
            return mappings.map { (map) -> (DropdownViewMap) in
                if let replacement = map.replacement {
                    return DropdownViewMap(value: map.value, replacement: translation?.localizeString(replacement) ?? map.replacement)
                } else {
                    return DropdownViewMap(value: map.value, replacement: nil)
                }

            }
        }
    }
    
    var value: Double {
        return buffer.last ?? defaultValue
    }
    
    var translation: ExperimentTranslationCollection?
    
    init(label: String, visibilityBuffer: DataBuffer?, defaultValue: Double, buffer: DataBuffer, mappings: [DropdownViewMap], translation: ExperimentTranslationCollection?) {
        self.label = label
        self.visibilityBuffer = visibilityBuffer
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
            
                    \(setVisiblity(id))
            
             
            }

            """
    }
    
    func setVisiblity(_ id: Int) -> String {
        
        guard let visibilityLabel = visibilityBuffer?.name else { return "" }
        
        return """
                if (data.hasOwnProperty(\"\(visibilityLabel)\")) {
                    var elementVisibilityIndicator = data[\"\(visibilityLabel)\"][\"data\"][data[\"\(visibilityLabel)\"][\"data\"].length-1];
                    var dropDownElement = document.getElementById(\"element\(id)\");
                    if (elementVisibilityIndicator <= 0.0 || elementVisibilityIndicator.length == 0) {
                        dropDownElement.style.display = \"none\";
                    } else {
                        dropDownElement.style.display = \"block\";
                    }
                }

            """
    }
    
    
}
