//
//  AppendAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class AppendAnalysis: ExperimentAnalysisModule {
    private let buffers: [DataBuffer]
    
    override init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String : AnyObject]?) {
        var buf = [DataBuffer]()
        
        for input in inputs {
            if let b = input.buffer {
                buf.append(b)
            }
        }
        
        buffers = buf
        
        super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        var result: [Double] = []
        
        #if DEBUG_ANALYSIS
            debug_noteInputs(inputs)
        #endif
        
        for b in buffers {
            result.appendContentsOf(b.toArray())
        }
        
        #if DEBUG_ANALYSIS
            debug_noteOutputs(result)
        #endif
        
        for output in outputs {
            if output.clear {
                output.buffer!.replaceValues(result)
            }
            else {
                output.buffer!.appendFromArray(result)
            }
        }
    }
}
