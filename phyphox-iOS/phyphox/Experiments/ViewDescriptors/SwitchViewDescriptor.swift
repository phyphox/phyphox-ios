//
//  SwitchViewDescriptor.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 21.10.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

struct SwitchViewDescriptor: ViewDescriptor, Equatable {
    
    let defaultValue: Double?
    let buffer: DataBuffer
    let label: String
    let translation: ExperimentTranslationCollection?
    
    var value: Double {
        return buffer.last ?? 0.0
    }
    
    init(label: String, translation: ExperimentTranslationCollection?, defaultValue: Double?, buffer: DataBuffer) {
        
        self.defaultValue = defaultValue
        self.buffer = buffer
        self.label = label
        self.translation = translation
    }
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        
        let defaultSwitchValue = (defaultValue == 1.0)
        
        return "<div style=\"font-size: 105%;\" class=\"switchElement\" id=\"element\(id)\"><span class=\"label\">\(localizedLabel)</span><input type=\"checkbox\" class=\"value\" id=\"radio\(id)\" \(defaultSwitchValue) ></input></div>"
    }
    
    func setDataHTMLWithID(_ id: Int) -> String {
        let bufferName = buffer.name
        
        return """
            function (data) {
                if (!data.hasOwnProperty("\(bufferName)"))
                    return;

                var x = data["\(bufferName)"]["data"][data["\(bufferName)"]["data"].length - 1];
                var radioButton = document.getElementById("radio\(id)");
            
                if (isNaN(x) || x == null || x == 0 || x == 0.0) {
                    radioButton.checked = false;
                } else {
                    radioButton.checked = true;
                }
            
                // Update value when checkbox state changes
                radioButton.onchange = function() {
                    var value = radioButton.checked ? 1.0 : 0.0;
                    ajax('control?cmd=set&buffer=\(buffer.name)&value='+value);
                };
            }
            
            
            """
    }
}


/**
 
 <multiply>
     <input clear="false">dropdown</input>
     <input type="value">10</input>
     <output clear="false">slider</output>
 </multiply>
 <add>
     <input clear="false">dropdown</input>
     <input type="value">0</input>
     <output clear="false">toggle</output>
 </add>
 */
