//
//  ExperimentAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

protocol ExperimentAnalysisDelegate : AnyObject {
    func analysisWillUpdate(analysis: ExperimentAnalysis)
    func analysisDidUpdate(analysis: ExperimentAnalysis)
}

private let analysisQueue = dispatch_queue_create("de.rwth-aachen.phyphox.analysis", DISPATCH_QUEUE_SERIAL)

final class ExperimentAnalysis : DataBufferObserver {
    let analyses: [ExperimentAnalysisModule]
    
    let sleep: Double
    let onUserInput: Bool
    
    weak var delegate: ExperimentAnalysisDelegate?
    
    private var editBuffers = Set<DataBuffer>()
    
    init(analyses: [ExperimentAnalysisModule], sleep: Double, onUserInput: Bool) {
        self.analyses = analyses
        
        self.sleep = max(1/30.0, sleep) //Max analysis rate: 30Hz
        self.onUserInput = onUserInput
    }
    
    /**
     Used to register a data buffer that receives data directly from a sensor or from the microphone
     */
    func registerSensorBuffer(dataBuffer: DataBuffer) {
        dataBuffer.addObserver(self)
    }
    
    /**
     Used to register a data buffer that receives data from user input
     */
    func registerEditBuffer(dataBuffer: DataBuffer) {
        dataBuffer.addObserver(self)
        editBuffers.insert(dataBuffer)
    }
    
    func dataBufferUpdated(buffer: DataBuffer) {
        if !onUserInput || editBuffers.contains(buffer) {
            setNeedsUpdate()
        }
    }
    
    private var busy = false
    
    /**
     Schedules an update.
     */
    func setNeedsUpdate() {
        if !busy {
            busy = true
            
            after(sleep, closure: {
                #if DEBUG
                    print("Analysis update")
                #endif
                
                self.delegate?.analysisWillUpdate(self)
                self.update {
                    self.delegate?.analysisDidUpdate(self)
                }
                
                self.busy = false
            })
        }
    }
    
    private func update(completion: Void -> Void) {
        let c = analyses.count-1
        
        for (i, analysis) in analyses.enumerate() {
            dispatch_async(analysisQueue, {
                analysis.setNeedsUpdate()
                if i == c {
                    mainThread {
                        completion()
                    }
                }
            })
        }
    }
}
