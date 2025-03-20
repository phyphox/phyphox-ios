//
//  ExperimentAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

extension String: AttributeKey {
    var rawValue: String {
        return self
    }
}

protocol ExperimentAnalysisDelegate: AnyObject {
    func analysisWillUpdate(_ analysis: ExperimentAnalysis)
    func analysisDidUpdate(_ analysis: ExperimentAnalysis)
    func analysisSkipped(_ analysis: ExperimentAnalysis)
}

final class ExperimentAnalysis {
    private let modules: [ExperimentAnalysisModule]
    
    private var cycle = 0

    private let sleep: Double
    private let dynamicSleep: DataBuffer?
    private let onUserInput: Bool
    
    private let requireFill: DataBuffer?
    private let requireFillThreshold: Int
    private let requireFillDynamic: DataBuffer?

    public let timedRun: Bool
    public let timedRunStartDelay: Double
    public let timedRunStopDelay: Double
    
    var running = false
    
    let timeReference: ExperimentTimeReference
    weak var delegate: ExperimentAnalysisDelegate?
    
    let sensorInputs: [ExperimentSensorInput]
    let audioInputs: [ExperimentAudioInput]


    public var queue: DispatchQueue?
    
    init(modules: [ExperimentAnalysisModule], sleep: Double, dynamicSleep: DataBuffer?, onUserInput: Bool, requireFill: DataBuffer?, requireFillThreshold: Int, requireFillDynamic: DataBuffer?, timedRun: Bool, timedRunStartDelay: Double, timedRunStopDelay: Double, timeReference: ExperimentTimeReference, sensorInputs: [ExperimentSensorInput], audioInputs: [ExperimentAudioInput]) {
        self.modules = modules
        self.sleep = sleep
        self.dynamicSleep = dynamicSleep
        self.onUserInput = onUserInput
        self.requireFill = requireFill
        self.requireFillThreshold = requireFillThreshold
        self.requireFillDynamic = requireFillDynamic

        self.timedRun = timedRun
        self.timedRunStartDelay = timedRunStartDelay
        self.timedRunStopDelay = timedRunStopDelay
        
        self.timeReference = timeReference
        
        self.sensorInputs = sensorInputs
        self.audioInputs = audioInputs
        
        for module in modules {
            for input in module.inputs {
                switch input {
                case .buffer(buffer: let buffer, data: _, usedAs: _, keep: _):
                    buffer.addObserver(self)
                case .value(value: _, usedAs: _):
                    continue
                }
            }
            
        }
    }
    
    private var busy = false
    private var requestedUpdateWhileBusy = false

    /**
     Schedules an update.
     */
    func setNeedsUpdate(isPreRun: Bool = false) {
        if isPreRun {
            cycle = 0
        }
        
        guard !busy else {
            requestedUpdateWhileBusy = true
            return
        }

        busy = true

        let delay = cycle > 1 ? max(1/100.0, dynamicSleep?.last ?? sleep) : 0

        after(delay) {
            if !self.running && self.cycle > 0 { //If the user stopped the experiment during sleep, we do not even want to start updating as we might end up overwriting the data the user wanted to pause on...
                self.busy = false
                return
            }

            self.delegate?.analysisWillUpdate(self)
            
            self.update {didExecute in
                let didRequestUpdateWhileBusy = self.requestedUpdateWhileBusy

                self.requestedUpdateWhileBusy = false
                self.busy = false
                if didExecute {
                    self.delegate?.analysisDidUpdate(self)
                } else {
                    self.delegate?.analysisSkipped(self)
                }

                if !isPreRun && (didRequestUpdateWhileBusy || !self.onUserInput) {
                    self.setNeedsUpdate()
                }
            }
        }
    }
    
    private func update(_ completion: @escaping (_ didExecute: Bool) -> Void) {

        for sensorInput in sensorInputs {
            sensorInput.updateGeneratedRate()
        }
        
        for audioInput in audioInputs {
            audioInput.outBuffer.appendFromArray(audioInput.backBuffer.readAndClear(reset: false))
        }
        
        if let requireFill = requireFill {
            let threshold: Int
            if let dynamic = requireFillDynamic?.last {
                threshold = Int(dynamic)
            } else {
                threshold = requireFillThreshold
            }
            if requireFill.count < threshold {
                mainThread {
                    completion(false)
                }
                return
            }
        }
        
        func inCycleList(thisCycle: Int, cycles: [(Int, Int)]) -> Bool {
            if cycles.count == 0 {
                return true
            }
            for cycle in cycles {
                if thisCycle < cycle.0 && cycle.0 >= 0 {
                    continue
                }
                if thisCycle > cycle.1 && cycle.1 >= 0 {
                    continue
                }
                return true
            }
            return false
        }
        
        let modulesInCycle = modules.filter{inCycleList(thisCycle: cycle, cycles: $0.cycles)}
        
        let c = modulesInCycle.count - 1
        
        let experimentTime = timeReference.getExperimentTime()
        let linearTime = timeReference.getLinearTime()
        let experimentOffset1970 = timeReference.getSystemTimeReferenceByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: experimentTime)).timeIntervalSince1970
        let linearOffset1970 = timeReference.getSystemTimeReferenceByIndex(i: 0).timeIntervalSince1970
        
        if (c >= 0) {
            queue?.async(execute: {
                for (i, analysis) in modulesInCycle.enumerated() {
                    analysis.setNeedsUpdate(experimentTime: experimentTime, linearTime: linearTime, experimentReference1970: experimentOffset1970, linearReference1970: linearOffset1970)
                    if i == c {
                        for audioInput in self.audioInputs {
                            if !audioInput.appendData {
                                audioInput.outBuffer.clear(reset: false)
                            }
                        }
                        mainThread {
                            self.cycle += 1
                            completion(true)
                        }
                    }
                }
            })
        } else {
            mainThread {
                self.cycle += 1
                completion(true)
            }
        }
    }
}

extension ExperimentAnalysis: DataBufferObserver {
    func dataBufferUpdated(_ buffer: DataBuffer) {
    }
    
    func userInputTriggered(_ buffer: DataBuffer) {
        setNeedsUpdate(isPreRun: !running)
    }
}

extension ExperimentAnalysis: Equatable {
    static func ==(lhs: ExperimentAnalysis, rhs: ExperimentAnalysis) -> Bool {
        return lhs.sleep == rhs.sleep &&
            lhs.dynamicSleep == rhs.dynamicSleep &&
            lhs.requireFill == rhs.requireFill &&
            lhs.requireFillThreshold == rhs.requireFillThreshold &&
            lhs.requireFillDynamic == rhs.requireFillDynamic &&
            lhs.modules == rhs.modules
    }
}
