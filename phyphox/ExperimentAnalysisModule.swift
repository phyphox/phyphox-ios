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
    
    internal var staticAnalysis = false {
        didSet {
            for out in outputs {
                out.buffer!.staticBuffer = staticAnalysis
            }
        }
    }
    
    internal var busy = false
    
    internal var executed = false
    
    init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String: AnyObject]?) {
        self.inputs = inputs
        self.outputs = outputs
    }
    
    func registerForUpdates() {
        for input in self.inputs {
            if input.buffer != nil {
                NSNotificationCenter.defaultCenter().addObserver(self, selector: "attemptUpdate", name: DataBufferReceivedNewValueNotification, object: input.buffer!)
            }
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    dynamic func attemptUpdate() {
        if (!staticAnalysis || !executed) && !busy {
            executed = true
            busy = true
            update()
            
            after(0.1, closure: { () -> Void in
                self.busy = false
            })
        }
    }
    
    internal func update() {
        fatalError("Subclasses of ExperimentAnalysisModule must override the update() method!")
    }
}
