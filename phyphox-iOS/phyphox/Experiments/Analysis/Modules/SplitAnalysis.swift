//
//  SplitAnalysis.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 01.07.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation


final class SplitAnalysis: AutoClearingExperimentAnalysisModule {
    
    private var data: ExperimentAnalysisDataInput? = nil
    private var index: ExperimentAnalysisDataInput? = nil
    private var overlap: ExperimentAnalysisDataInput? = nil
    private var arrayIns: [ExperimentAnalysisDataInput] = []
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput]  , additionalAttributes: AttributeContainer ) throws {
        for input in inputs {
            
            print("split input ", input)
            
            if input.asString == "index" {
                index = input
            }
            else if input.asString == "overlap" {
                overlap = input
            }
            else {
                if !input.isBuffer {
                    throw SerializationError.genericError(message: "Error: Regular inputs of the split module besides data, index or length must be buffers.")
                } else {
                    arrayIns.append(input)
                }
            }
        }
        
        if (outputs.count < 1) {
            throw SerializationError.genericError(message: "Error: No output for split-module specified.")
        }
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    // TODO write a code to update the buffer with split module
    override func update() {
        print("split update data ", data?.asString)
    }
    
}
