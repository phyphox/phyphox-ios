//
//  ButtonViewDescriptor.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 13.11.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreGraphics

struct ButtonViewDescriptor: ViewDescriptor, Equatable {
    static func == (lhs: ButtonViewDescriptor, rhs: ButtonViewDescriptor) -> Bool {
        return lhs.label == rhs.label &&
            lhs.translation == rhs.translation &&
            lhs.dataFlow.elementsEqual(rhs.dataFlow, by: { (l, r) -> Bool in
                return l.input == r.input && l.output == r.output
            }) &&
            lhs.triggers.elementsEqual(rhs.triggers)
    }

    let dataFlow: [(input: ExperimentAnalysisDataInput, output: DataBuffer)]
    let triggers: [String]

    let label: String
    let translation: ExperimentTranslationCollection?
    
    let mappings: [ValueViewMap]
    
    let buffer: DataBuffer?

    init(label: String, translation: ExperimentTranslationCollection?, dataFlow: [(input: ExperimentAnalysisDataInput, output: DataBuffer)], triggers: [String], mappings: [ValueViewMap], buffer: DataBuffer?) {
        self.dataFlow = dataFlow
        self.triggers = triggers
        
        self.label = label
        self.translation = translation
        
        let translatedMappings = mappings.compactMap { map in (translation?.localizeString(map.replacement) ?? map.replacement).map { ValueViewMap(range: map.range, replacement: $0) } }
        
        self.mappings = translatedMappings
        
        self.buffer = buffer
    }
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        return "<div style=\"font-size: 105%;\" class=\"buttonElement\" id=\"element\(id)\"><button class=\"valueNumber\" onclick=\"ajax('control?cmd=trigger&element=\(id)');\">\(localizedLabel)</button></div>"
    }
    
    func setDataHTMLWithID(_ id: Int) -> String {
        let bufferName = buffer?.name ?? ""
        var mappingCode = "if (isNaN(x) || x == null) { v = \"\(localizedLabel)\" }"
        for mapping in mappings {
            let str = mapping.replacement
            
            if mapping.range.upperBound.isFinite && mapping.range.lowerBound.isFinite {
                mappingCode += "else if (x >= \(mapping.range.lowerBound) && x <= \(mapping.range.upperBound)) {v = \"\(str)\";}"
            }
            else if mapping.range.upperBound.isFinite {
                mappingCode += "else if (x <= \(mapping.range.upperBound)) {v = \"\(str)\";}"
            }
            else if mapping.range.lowerBound.isFinite {
                mappingCode += "else if (x >= \(mapping.range.lowerBound)) {v = \"\(str)\";}"
            }
            else {
                mappingCode += "else if (true) {v = \"\(str)\";}"
            }
        }
        
        return "function (data) {" +
        "    if (!data.hasOwnProperty(\"\(bufferName)\"))" +
        "        return;" +
        " var x = data[\"\(bufferName)\"][\"data\"][data[\"\(bufferName)\"][\"data\"].length-1]; " +
        "    var v = null;" +
        mappingCode + " else {v = \"\(localizedLabel)\";}" +
        "    var valueNumber = document.getElementById(\"element\(id)\").getElementsByClassName(\"valueNumber\")[0];" +
        "    valueNumber.textContent = v;" +
        "}"
    
    }
}
