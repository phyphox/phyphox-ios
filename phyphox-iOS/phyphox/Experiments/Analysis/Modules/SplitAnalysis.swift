//
//  SplitAnalysis.swift
//  phyphox
//
//  Created by Sebastian Staacks on 07.05.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

final class SplitAnalysis: AutoClearingExperimentAnalysisModule {
    private var dataIn: MutableDoubleArray!
    private var indexIn: ExperimentAnalysisDataInput?
    private var overlapIn: ExperimentAnalysisDataInput?
    
    private var out1Out: ExperimentAnalysisDataOutput?
    private var out2Out: ExperimentAnalysisDataOutput?
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        
        for input in inputs {
            if input.asString == "data" {
                switch input {
                case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                    dataIn = data
                case .value(value: _, usedAs: _):
                    break
                }
            }
            else if input.asString == "index" {
                indexIn = input
            }
            else if input.asString == "overlap" {
                overlapIn = input
            }
            else {
                print("Error: Invalid analysis input: \(String(describing: input.asString))")
            }
        }
        
        for output in outputs {
            if output.asString == "out1" {
                out1Out = output
            }
            else if output.asString == "out2" {
                out2Out = output
            }
            else {
                if (out1Out == nil) {
                    out1Out = output
                } else {
                    out2Out = output
                }
            }
        }
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        
        let inArray = dataIn.data
        
        let index = Int(indexIn?.getSingleValue() ?? Double(inArray.count))
        let overlap = min(index, Int(overlapIn?.getSingleValue() ?? 0.0))
        
        if let out1Out = out1Out {
            switch out1Out {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(Array(inArray[0..<index]))
            }
        }
        
        if let out2Out = out2Out {
            switch out2Out {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(Array(inArray[index-overlap..<inArray.count]))
            }
        }
        
    }
}
