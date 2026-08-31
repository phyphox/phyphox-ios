//
//  FormulaAnalysis.swift
//  phyphox
//
//  Created by Sebastian Staacks on 19.04.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation

final class FormulaAnalysis: AutoClearingExperimentAnalysisModule {
    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [
            AnalysisIOSlot(name: "in", asRequired: false, repeatOffset: 0, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 0)
        ], outputs: [
            AnalysisIOSlot(name: "out", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
        ])
    }
    let parser: FormulaParser
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        let attributes = additionalAttributes.attributes(keyedBy: String.self)
        
        //A missing formula attribute rejects the file (matching Android)
        guard let formula: String = try attributes.optionalValue(for: "formula") else {
            throw SerializationError.genericError(message: "Formula module needs a formula.")
        }
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
            case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                inArrays.append(data.data)
            case .value(value: let value, usedAs: _):
                inArrays.append([value])
            }
        }
        
        let result = parser.execute(buffers: inArrays)
        
        if let output = outputs.first {
            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(result)
            }
        }
        
    }
}
