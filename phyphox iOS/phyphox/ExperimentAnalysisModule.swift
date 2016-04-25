//
//  ExperimentAnalysisModule.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

/**
 Abstract class providing an Analysis module for Experiments
 */
class ExperimentAnalysisModule {
    /**
     Inouts. Either containing a buffer, or a fixed value.
     */
    internal var inputs: [ExperimentAnalysisDataIO]
    
    /**
     Output buffers.
     */
    internal var outputs: [ExperimentAnalysisDataIO]
    
    private var executed = false
    
    internal var staticAnalysis = false {
        didSet {
            for out in outputs {
                out.buffer!.staticBuffer = staticAnalysis
            }
        }
    }
    
    internal var timestamp: NSTimeInterval = 0.0

    init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String: AnyObject]?) {
        self.inputs = inputs
        self.outputs = outputs
    }
    
    /**
     Updates immediately.
     */
    func setNeedsUpdate(timestamp: NSTimeInterval) {
        if !staticAnalysis || !executed {
            if NSThread.isMainThread() {
                print("Analysis should run in the background!")
            }
            self.timestamp = timestamp
            
            willUpdate()
            update()
            didUpdate()
            executed = true
        }
    }
    
    #if DEBUG
    internal func debug_noteInputs(inputs: AnyObject) {
        print("\(self.dynamicType) inputs: \(inputs)")
    }
    
    internal func debug_noteOutputs(outputs: AnyObject) {
        print("\(self.dynamicType) outputs: \(outputs)")
    }
    #endif
    
    internal func willUpdate() {
        
    }
    
    internal func didUpdate() {
        for input in inputs {
            if input.clear {
                input.buffer?.clear()
            }
        }
    }
    
    internal func update() {
        
    }
}
