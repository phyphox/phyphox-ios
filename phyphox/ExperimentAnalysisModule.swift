//
//  ExperimentAnalysisModule.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
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
    
    private var staticAnalysis = false {
        didSet {
            for out in outputs {
                out.buffer!.staticBuffer = staticAnalysis
            }
        }
    }
    
    private var executed = false
    
    init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String: AnyObject]?) {
        self.inputs = inputs
        self.outputs = outputs
    }
    
    /**
     Updates immediately.
     */
    func setNeedsUpdate() {
        if !staticAnalysis || !executed {
            if NSThread.isMainThread() {
                print("Analysis should run in the background!")
            }
            
            update()
            executed = true
        }
    }
    
    internal func debug_noteInputs(inputs: AnyObject) {
        print("\(self.dynamicType) inputs: \(inputs)")
    }
    
    internal func debug_noteOutputs(outputs: AnyObject) {
        print("\(self.dynamicType) outputs: \(outputs)")
    }
    
    internal func update() {
        fatalError("Subclasses of ExperimentAnalysisModule must override the update() method!")
    }
}
