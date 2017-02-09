//
//  ButtonViewDescriptor.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 13.11.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//


import Foundation
import CoreGraphics

final class ButtonViewDescriptor: ViewDescriptor {
    let inputs: [ExperimentAnalysisDataIO]
    let outputs: [DataBuffer]
    
    init(label: String, translation: ExperimentTranslationCollection?, inputs: [ExperimentAnalysisDataIO], outputs: [DataBuffer]) {
        self.inputs = inputs
        self.outputs = outputs
        
        super.init(label: label, translation: translation)
    }
    
    override func onTrigger() {
        for (i, output) in self.outputs.enumerate() {
            if self.inputs.count > i {
                let input = self.inputs[i]
                if input.value != nil {
                    output.replaceValues([input.value!])
                } else if input.buffer != nil {
                    output.replaceValues(input.buffer!.toArray())
                } else {
                    output.clear()
                }
            }
        }
    }
    
    override func generateViewHTMLWithID(id: Int) -> String {
        return "<div style=\"font-size: 120%;\" class=\"buttonElement\" id=\"element\(id)\"><button onclick=\"$.getJSON('control?cmd=trigger&element=\(id)')\">\(localizedLabel)</button></div>"
    }
}

