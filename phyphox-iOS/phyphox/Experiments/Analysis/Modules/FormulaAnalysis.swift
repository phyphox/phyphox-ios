//
//  FormulaAnalysis.swift
//  phyphox
//
//  Created by Sebastian Staacks on 19.04.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation

final class FormulaAnalysis: AutoClearingExperimentAnalysisModule {
    let parser: FormulaParser
    
    required init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: AttributeContainer) throws {
        let attributes = additionalAttributes.attributes(keyedBy: String.self)
        
        let formula = try attributes.optionalValue(for: "formula") ?? ""
        do {
            parser = try FormulaParser(formula: formula)
        } catch FormulaParser.FormulaError.parseError(let message) {
            throw SerializationError.genericError(message: message)
        }
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        var inArrays: [[Double]] = []
        for input in inputs {
            switch input {
            case .buffer(buffer: _, data: let data, usedAs: _, clear: _):
                inArrays.append(data.data)
            case .value(value: let value, usedAs: _):
                inArrays.append([value])
            }
        }
        
        let result = parser.execute(buffers: inArrays)
        
        if let output = outputs.first {
            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, clear: _):
                buffer.appendFromArray(result)
            default: break
            }
        }
        
    }
}
