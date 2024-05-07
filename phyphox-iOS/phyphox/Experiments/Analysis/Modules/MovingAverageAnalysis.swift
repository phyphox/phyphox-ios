//
//  MovingAverageAnalysis.swift
//  phyphox
//
//  Created by Sebastian Staacks on 07.05.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

final class MovingAverageAnalysis: AutoClearingExperimentAnalysisModule {
    private var dataIn: MutableDoubleArray!
    private var widthIn: ExperimentAnalysisDataInput?
    
    private var dataOut: ExperimentAnalysisDataOutput?
    
    private let dropIncomplete: Bool
        
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        
        let attributes = additionalAttributes.attributes(keyedBy: String.self)
        dropIncomplete = try attributes.optionalValue(for: "dropIncomplete") ?? false
        
        for input in inputs {
            if input.asString == "data" {
                switch input {
                case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                    dataIn = data
                case .value(value: _, usedAs: _):
                    break
                }
            }
            else if input.asString == "width" {
                widthIn = input
            }
            else {
                print("Error: Invalid analysis input: \(String(describing: input.asString))")
            }
        }
        
        for output in outputs {
            if dataOut == nil {
                dataOut = output
            }
            else {
                print("Error: Invalid analysis output: \(String(describing: output.asString))")
            }
        }
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        
        let inArray = dataIn.data
        
        let width = Int(widthIn?.getSingleValue() ?? 10.0)
        
        let start = dropIncomplete ? width : 0
        if start >= inArray.count {
            return
        }
        
        var result: [Double] = []
                
        for i in start..<inArray.count {
            let substart = min(i-width, 0)
            let sum = inArray[substart ... i].reduce(0.0, +)
            result.append(sum / (Double(i - substart + 1)))
        }
        
        if let dataOut = dataOut {
            switch dataOut {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(result)
            }
        }
    }
}
