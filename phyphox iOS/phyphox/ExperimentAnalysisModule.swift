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
    
    fileprivate var executed = false
    
    internal var staticAnalysis = false {
        didSet {
            for out in outputs {
                out.buffer!.staticBuffer = staticAnalysis
            }
        }
    }
    
    internal var timestamp: TimeInterval = 0.0

    init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String: AnyObject]?) throws {
        self.inputs = inputs
        self.outputs = outputs
    }
    
    /**
     Updates immediately.
     */
    func setNeedsUpdate(_ timestamp: TimeInterval) {
        if !staticAnalysis || !executed {
            if Thread.isMainThread {
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
        print("\(type(of: self)) inputs: \(inputs)")
    }
    
    internal func debug_noteOutputs(outputs: AnyObject) {
        print("\(type(of: self)) outputs: \(outputs)")
    }
    #endif
    
    internal func willUpdate() {
        
    }
    
    internal func didUpdate() {
        for input in inputs {
            if input.clear && (input.buffer?.staticBuffer == false) && (input.buffer?.attachedToTextField == false) {
                input.buffer?.clear()
            }
        }
    }
    
    internal func update() {
        
    }
}
