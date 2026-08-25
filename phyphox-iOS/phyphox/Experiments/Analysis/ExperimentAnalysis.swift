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
    
    var running = false {
        didSet {
            if !running {
                //Stopping re-exempts the next run from the requireFill gate, like Android
                //resetting lastAnalysis in stopAllIO
                didRunSinceStart = false
            }
        }
    }

    //Whether an analysis run has been carried out since the experiment was opened or started
    //(Android: lastAnalysis != 0)
    private var didRunSinceStart = false
    
    let timeReference: ExperimentTimeReference
    weak var delegate: ExperimentAnalysisDelegate?
    
    let sensorInputs: [ExperimentSensorInput]
    let audioInputs: [ExperimentAudioInput]


    public var queue: DispatchQueue?

    //The experiment-wide data lock, wired up in Experiment.init. A cycle's writes go through it so
    //remote /get reads see coherent analysis output (see BufferLock).
    weak var dataLock: BufferLock?

    //Runs an analysis cycle's writes as one atomic group; before the lock is wired up, or when
    //there is none, the writes run directly.
    private func writeLocked(_ body: () -> Void) {
        if let dataLock = dataLock {
            dataLock.write(body)
        } else {
            body()
        }
    }

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
    
    ///Passes a clear-data reset on to the modules, re-arming static modules whose buffers were
    ///reset (Android does this through the buffer notification, see AnalysisModule.notifyUpdate).
    func notifyBuffersReset(_ resetBuffers: Set<ObjectIdentifier>) {
        for module in modules {
            module.notifyBuffersReset(resetBuffers)
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
    
    private func inCycleList(thisCycle: Int, cycles: [(Int, Int)]) -> Bool {
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

    ///The modules that run in the given cycle, honoring their cycles attribute
    private func modulesInCycle(_ cycle: Int) -> [ExperimentAnalysisModule] {
        return modules.filter { inCycleList(thisCycle: cycle, cycles: $0.cycles) }
    }

    ///Whether the requireFill gate holds this run back. The first run after opening or starting
    ///is exempt: it is the pass that initializes buffers, and it has to run while the required
    ///container is still empty (Android: the lastAnalysis != 0 condition in processAnalysis).
    private func requireFillGateBlocks() -> Bool {
        guard let requireFill = requireFill, didRunSinceStart else { return false }

        let threshold: Int
        if let dynamic = requireFillDynamic?.last {
            threshold = Int(dynamic)
        } else {
            threshold = requireFillThreshold
        }

        return requireFill.count < threshold
    }

    ///Runs one analysis pass as the given cycle number and reports whether it executed, waiting
    ///for it to finish. This is update() itself - the requireFill gate, the module selection,
    ///the experiment time and the bookkeeping are all the production path; only the explicit
    ///cycle number and the waiting are test-specific, so that the analysis golden-vector runner
    ///pins the real path rather than a second implementation of it.
    ///
    ///Not for the main thread and not for the analysis queue: update() delivers its completion
    ///on the main thread and runs the modules on the analysis queue, both of which this waits
    ///for. The sleep, dynamicSleep and onUserInput scheduling around update() lives in
    ///setNeedsUpdate and is deliberately not involved - the caller decides when a cycle runs.
    @discardableResult
    func runCycle(_ cycle: Int) -> Bool {
        precondition(!Thread.isMainThread, "runCycle waits for a completion delivered on the main thread")

        self.cycle = cycle

        let finished = DispatchSemaphore(value: 0)
        var didExecute = false

        update { executed in
            didExecute = executed
            finished.signal()
        }

        finished.wait()

        return didExecute
    }

    private func update(_ completion: @escaping (_ didExecute: Bool) -> Void) {

        for sensorInput in sensorInputs {
            sensorInput.updateGeneratedRate()
        }
        
        writeLocked {
            for audioInput in audioInputs {
                audioInput.outBuffer.appendFromArray(audioInput.backBuffer.readAndClear(reset: false))
            }
        }
        
        if requireFillGateBlocks() {
            mainThread {
                completion(false)
            }
            return
        }
        
        let modulesInCycle = self.modulesInCycle(cycle)
        
        let c = modulesInCycle.count - 1
        
        let experimentTime = timeReference.getExperimentTime()
        let linearTime = timeReference.getLinearTime()
        let experimentOffset1970 = timeReference.getSystemTimeReferenceByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: experimentTime)).timeIntervalSince1970
        let linearOffset1970 = timeReference.getSystemTimeReferenceByIndex(i: 0).timeIntervalSince1970
        
        if (c >= 0) {
            guard let queue = queue else {
                //Without a queue the modules cannot run. Complete as skipped instead of
                //returning silently, which would leave the busy flag set forever.
                mainThread {
                    completion(false)
                }
                return
            }
            queue.async(execute: {
                //A whole analysis cycle's buffer writes are one atomic group, so a remote /get read
                //sees a coherent snapshot across every module's outputs rather than a state where
                //some modules have run and others have not (see BufferLock). The completion is
                //dispatched to the main thread *outside* the lock - holding a barrier across a main
                //hop would deadlock.
                self.writeLocked {
                    for analysis in modulesInCycle {
                        analysis.setNeedsUpdate(experimentTime: experimentTime, linearTime: linearTime, experimentReference1970: experimentOffset1970, linearReference1970: linearOffset1970)
                    }
                    for audioInput in self.audioInputs {
                        if !audioInput.appendData {
                            audioInput.outBuffer.clear(reset: false)
                        }
                    }
                }
                mainThread {
                    self.cycle += 1
                    self.didRunSinceStart = true
                    completion(true)
                }
            })
        } else {
            mainThread {
                self.cycle += 1
                self.didRunSinceStart = true
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
