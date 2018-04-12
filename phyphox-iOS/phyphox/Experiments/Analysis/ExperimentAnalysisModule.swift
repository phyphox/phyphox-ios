//
//  ExperimentAnalysisModule.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

/**
 Abstract class providing an Analysis module for Experiments
 */
class ExperimentAnalysisModule {
    /**
     Inputs. Either containing a buffer, or a fixed value.
     */
    var inputs: [ExperimentAnalysisDataIO]
    
    /**
     Output buffers.
     */
    var outputs: [ExperimentAnalysisDataIO]
    
    var timestamp: TimeInterval = 0.0

    init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String: String]) throws {
        self.inputs = inputs
        self.outputs = outputs
    }
    
    /**
     Updates immediately.
     */
    func setNeedsUpdate(_ timestamp: TimeInterval) {
        if Thread.isMainThread {
            print("Analysis should run in the background!")
        }
        self.timestamp = timestamp
        willUpdate()
        update()
        didUpdate()
    }
    
    #if DEBUG
    func debug_noteInputs(inputs: AnyObject) {
        print("\(type(of: self)) inputs: \(inputs)")
    }
    
    func debug_noteOutputs(outputs: AnyObject) {
        print("\(type(of: self)) outputs: \(outputs)")
    }
    #endif
    
    func willUpdate() {
        
    }
    
    func didUpdate() {
        for input in inputs {
            switch input {
            case .value(value: _, usedAs: _):
                break
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear && !buffer.staticBuffer && !buffer.attachedToTextField {
                    buffer.clear()
                }
            }
        }
    }
    
    func update() {
        
    }
}