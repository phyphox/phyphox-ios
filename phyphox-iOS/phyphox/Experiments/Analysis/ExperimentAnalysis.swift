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

protocol ExperimentAnalysisDelegate: class {
    func analysisWillUpdate(_ analysis: ExperimentAnalysis)
    func analysisDidUpdate(_ analysis: ExperimentAnalysis)
}

final class ExperimentAnalysis {
    private let modules: [ExperimentAnalysisModule]
    
    private var cycle = 0

    private let sleep: Double
    private let dynamicSleep: DataBuffer?
    private let onUserInput: Bool

    public let timedRun: Bool
    public let timedRunStartDelay: Double
    public let timedRunStopDelay: Double
    
    var running = false
    
    let timeReference: ExperimentTimeReference
    weak var delegate: ExperimentAnalysisDelegate?
    
    let sensorInputs: [ExperimentSensorInput]

    public var queue: DispatchQueue?
    
    init(modules: [ExperimentAnalysisModule], sleep: Double, dynamicSleep: DataBuffer?, onUserInput: Bool, timedRun: Bool, timedRunStartDelay: Double, timedRunStopDelay: Double, timeReference: ExperimentTimeReference, sensorInputs: [ExperimentSensorInput]) {
        self.modules = modules
        self.sleep = sleep
        self.dynamicSleep = dynamicSleep
        self.onUserInput = onUserInput

        self.timedRun = timedRun
        self.timedRunStartDelay = timedRunStartDelay
        self.timedRunStopDelay = timedRunStopDelay
        
        self.timeReference = timeReference
        
        self.sensorInputs = sensorInputs
        
        if onUserInput {
            for module in modules {
                for input in module.inputs {
                    switch input {
                    case .buffer(buffer: let buffer, usedAs: _, clear: _):
                        buffer.addObserver(self)
                    case .value(value: _, usedAs: _):
                        continue
                    }
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

        let delay = cycle > 0 ? max(1/50.0, dynamicSleep?.last ?? sleep) : 0

        after(delay) {
            if !self.running && self.cycle > 0 { //If the user stopped the experiment during sleep, we do not even want to start updating as we might end up overwriting the data the user wanted to pause on...
                self.busy = false
                return
            }

            self.delegate?.analysisWillUpdate(self)
            
            self.update {
                let didRequestUpdateWhileBusy = self.requestedUpdateWhileBusy

                self.requestedUpdateWhileBusy = false
                self.busy = false
                self.delegate?.analysisDidUpdate(self)

                if self.cycle > 1 && (didRequestUpdateWhileBusy || !self.onUserInput) {
                    self.setNeedsUpdate()
                }
            }
        }
    }
    
    private func update(_ completion: @escaping () -> Void) {

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
        
        for sensorInput in sensorInputs {
            sensorInput.updateGeneratedRate()
        }
        
        if (c >= 0) {
            for (i, analysis) in modulesInCycle.enumerated() {
                queue?.async(execute: {
                    analysis.setNeedsUpdate(experimentTime: experimentTime, linearTime: linearTime, experimentReference1970: experimentOffset1970, linearReference1970: linearOffset1970)
                    if i == c {
                        mainThread {
                            self.cycle += 1
                            completion()
                        }
                    }
                })
            }
        } else {
            mainThread {
                self.cycle += 1
                completion()
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
            lhs.modules == rhs.modules
    }
}
