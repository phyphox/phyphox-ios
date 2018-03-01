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
    func analysisWillUpdate(_ analysis: ExperimentAnalysis)
    func analysisDidUpdate(_ analysis: ExperimentAnalysis)
}

private let analysisQueue = DispatchQueue(label: "de.rwth-aachen.phyphox.analysis", attributes: [])

protocol ExperimentAnalysisTimeManager : AnyObject {
    func getCurrentTimestamp() -> TimeInterval
}

final class ExperimentAnalysis : DataBufferObserver {
    let analyses: [ExperimentAnalysisModule]
    
    let sleep: Double
    let dynamicSleep: DataBuffer?
    let onUserInput: Bool
    
    var running = false
    
    weak var timeManager: ExperimentAnalysisTimeManager?
    weak var delegate: ExperimentAnalysisDelegate?
    
    private var editBuffers = [DataBuffer]()
    
    private(set) var timestamp: TimeInterval = 0.0

    init(analyses: [ExperimentAnalysisModule], sleep: Double, dynamicSleep: DataBuffer?, onUserInput: Bool) {
        self.analyses = analyses
        
        self.sleep = sleep
        self.dynamicSleep = dynamicSleep
        self.onUserInput = onUserInput
    }
    
    /**
     Used to register a data buffer that receives data directly from a sensor or from the microphone
     */
    func registerSensorBuffer(_ dataBuffer: DataBuffer) {
        dataBuffer.addObserver(self)
    }
    
    /**
     Used to register a data buffer that receives data from user input
     */
    func registerEditBuffer(_ dataBuffer: DataBuffer) {
        dataBuffer.addObserver(self)
        editBuffers.append(dataBuffer)
    }
    
    func dataBufferUpdated(_ buffer: DataBuffer, noData: Bool) {
        if (!onUserInput || editBuffers.contains(where: { $0.name == buffer.name })) && !noData {
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
            after(max(1/50.0, dynamicSleep?.last ?? sleep), closure: {
                if !self.running && !self.onUserInput { //If the user stopped the experiment during sleep, we do not even want to start updating as we might end up overwriting the data the user wanted to pause on...
                    self.busy = false
                    return
                }
                
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
    
    private func update(_ completion: @escaping () -> Void) {
        let c = analyses.count-1
        
        for (i, analysis) in analyses.enumerated() {
            analysisQueue.async(execute: {
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
