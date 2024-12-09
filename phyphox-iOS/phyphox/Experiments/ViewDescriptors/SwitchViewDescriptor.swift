//
//  SwitchViewDescriptor.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 21.10.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

struct SwitchViewDescriptor: ViewDescriptor, Equatable {
    
    let defaultValue: Double
    let buffer: DataBuffer
    let label: String
    let translation: ExperimentTranslationCollection?
    
    var value: Double {
        return buffer.last ?? defaultValue
    }
    
    init(label: String, translation: ExperimentTranslationCollection?, defaultValue: Double, buffer: DataBuffer) {
        
        self.defaultValue = defaultValue
        self.buffer = buffer
        self.label = label
        self.translation = translation
    }
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        
        return "<div style=\"font-size: 105%;\" class=\"switchElement\" id=\"element\(id)\"><span class=\"label\">\(localizedLabel)</span><input type=\"radio\" class=\"value\" id=\"radio\(id)\" onclick=\"ajax('control?cmd=trigger&element=\(id)');\" ></div>"
    }
    
    func setDataHTMLWithID(_ id: Int) -> String {
        let bufferName = buffer.name
        
        return """
            function (data) {
                if (!data.hasOwnProperty("\(bufferName)"))
                    return;

                var x = data["\(bufferName)"]["data"][data["\(bufferName)"]["data"].length - 1];
                var radioButton = document.getElementById("radio\(id)");

                if (isNaN(x) || x == null || x == 0) {
                    radioButton.checked = false;
                    radioButton.disabled = true;
                } else {
                    radioButton.checked = true;
                    radioButton.disabled = false;
                }
            }
            """
    }
}
