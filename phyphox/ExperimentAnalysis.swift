//
//  ExperimentAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

/**
 Abstract class providing an Analysis module for Experiments
 */
public class ExperimentAnalysis {
    internal let experiment: Experiment
    
    /**
     Array of input keys. Either key for buffer, or a fixed value (double)
     */
    internal var inputs: [String]
    
    /**
     Output buffers.
     */
    internal var outputs: [DataBuffer]
    
    /**
     Fixed values are stored in this dictionary, with their corresponding indices in the `inputs` array.
     */
    internal var fixedValues: [Int : Double] = [:]

    internal var staticAnalysis = false {
        didSet {
            for buffer in outputs {
                buffer.staticBuffer = staticAnalysis
            }
        }
    }
    internal var executed = false
    
    init(experiment: Experiment, inputs: [String], outputs: [DataBuffer]) {
        self.experiment = experiment
        self.inputs = inputs
        self.outputs = outputs
        
        for (i, value) in inputs.enumerate() {
            if (true/**check if value is valid identifier*/) {
                let d = Double(value)
                
                if (d != nil) {
                    fixedValues[i] = d
                }
            }
        }
    }
    
    func getBufferForKey(key: String) -> DataBuffer? {
        let buffer = DataBuffer(name: "", size: 0) as DataBuffer?//get buffer from experiment for key: experiment.getBuffer(key);
        
        return buffer;
    }
    
    func getSingleValueFromUserString(key: String) -> Double? {
        let buffer = getBufferForKey(key)
        
        if (buffer != nil) {
            return buffer!.lastValue
        }
        else {
            return Double(key)
        }
    }
    
    func attemptUpdate() {
        if (!staticAnalysis || !executed) {
            executed = true
            update()
        }
    }
    
    func update() {
        fatalError("Subclasses of ExperimentAnalysis must override the update() method!")
    }
}
