//
//  ExperimentAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

protocol ExperimentAnalysisDelegate : AnyObject {
    func analysisWillUpdate(analysis: ExperimentAnalysis)
    func analysisDidUpdate(analysis: ExperimentAnalysis)
}

private let analysisQueue = dispatch_queue_create("de.rwth-aachen.phyphox.analysis", DISPATCH_QUEUE_SERIAL)

protocol ExperimentAnalysisTimeManager : AnyObject {
    func getCurrentTimestamp() -> NSTimeInterval
}

final class ExperimentAnalysis : DataBufferObserver {
    let analyses: [ExperimentAnalysisModule]
    
    let sleep: Double
    let onUserInput: Bool
    
    var running = false
    
    weak var timeManager: ExperimentAnalysisTimeManager?
    weak var delegate: ExperimentAnalysisDelegate?
    
    private var editBuffers = Set<DataBuffer>()
    
    private(set) var timestamp: NSTimeInterval = 0.0

    init(analyses: [ExperimentAnalysisModule], sleep: Double, onUserInput: Bool) {
        self.analyses = analyses
        
        self.sleep = max(1/50.0, sleep) //Max analysis rate: 30Hz
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
    
    func dataBufferUpdated(buffer: DataBuffer, noData: Bool) {
        if (!onUserInput || editBuffers.contains(buffer)) && !noData {
            setNeedsUpdate()
        }
    }
    
    func analysisComplete() {
        
    }
    
    func reset() {
        timestamp = 0.0
    }
    
    private var busy = false
    
    /**
     Schedules an update.
     */
    func setNeedsUpdate() {
        if !busy {
            busy = true
            after(sleep, closure: {
                self.timestamp = self.timeManager?.getCurrentTimestamp() ?? 0.0
                
                self.delegate?.analysisWillUpdate(self)
                self.update {
                    self.busy = false
                    self.delegate?.analysisDidUpdate(self)
                    
                    //Originally, Jonas set up a clever construct of notifications to let the app decide when recalculation is necessary, which will be disabled to some extend by the following. The reason for this is, that in the original design analysis could only be triggered by user input or new sensor data. But there are some experiments, which simply generate a sequence of values and recalculate the input to their own next analysis process, which cannot not trigger it using a notification. If it was triggered only by notification, it would run indefinitely while the experiment is stopped.
                    //Therefore: TODO Make this more clever by at least checking if an input has been changed by this analysis run after its output has been calculated
                    if self.running && !self.onUserInput {
                        self.setNeedsUpdate()
                    }
                }
            })
        }
    }
    
    private func update(completion: Void -> Void) {
        print("UPDATE")
        let c = analyses.count-1
        
        for (i, analysis) in analyses.enumerate() {
            dispatch_async(analysisQueue, {
                analysis.setNeedsUpdate(self.timestamp)
                if i == c {
                    mainThread {
                        completion()
                    }
                }
            })
        }
    }
}
