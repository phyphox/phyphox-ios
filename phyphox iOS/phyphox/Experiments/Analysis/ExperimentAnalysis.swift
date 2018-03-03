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

final class ExperimentAnalysis: DataBufferObserver {
    private let modules: [ExperimentAnalysisModule]
    
    private let sleep: Double
    private let dynamicSleep: DataBuffer?

    let inputBuffers: [String: DataBuffer]
    let outputBuffers: [String: DataBuffer]

    var running = false
    
    weak var timeManager: ExperimentAnalysisTimeManager?
    weak var delegate: ExperimentAnalysisDelegate?

    private var timestamp: TimeInterval = 0.0

    init(modules: [ExperimentAnalysisModule], sleep: Double, dynamicSleep: DataBuffer?) {
        self.modules = modules
        let inputBufferTuples = modules.flatMap({ $0.inputs.flatMap { input -> (String, DataBuffer)? in
            if let buffer = input.buffer {
                return (buffer.name, buffer)
            }
            else {
                return nil
            }
            }
        })

        inputBuffers = Dictionary(inputBufferTuples, uniquingKeysWith: { first, _ in first })

        let outputBufferTuples = modules.flatMap({ $0.outputs.flatMap { output -> (String, DataBuffer)? in
            if let buffer = output.buffer {
                return (buffer.name, buffer)
            }
            else {
                return nil
            }
            }
        })

        outputBuffers = Dictionary(outputBufferTuples, uniquingKeysWith: { first, _ in first })

        self.sleep = sleep
        self.dynamicSleep = dynamicSleep

        let pureInputs = inputBuffers.filter { outputBuffers[$0.key] == nil }

        pureInputs.forEach {
            $0.value.addObserver(self, alwaysNotify: false)
        }
    }

    func dataBufferUpdated(_ buffer: DataBuffer) {
        setNeedsUpdate()
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
                if !self.running { //If the user stopped the experiment during sleep, we do not even want to start updating as we might end up overwriting the data the user wanted to pause on...
                    self.busy = false
                    return
                }
                
                self.timestamp = self.timeManager?.getCurrentTimestamp() ?? 0.0
                
                self.delegate?.analysisWillUpdate(self)

                self.update {
                    self.busy = false
                    self.delegate?.analysisDidUpdate(self)
                }
            })
        }
    }
    
    private func update(_ completion: @escaping () -> Void) {
        let c = modules.count-1
        
        for (i, analysis) in modules.enumerated() {
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
