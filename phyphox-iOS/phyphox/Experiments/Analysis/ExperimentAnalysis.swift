//
//  ExperimentAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

protocol ExperimentAnalysisDelegate: class {
    func analysisWillUpdate(_ analysis: ExperimentAnalysis)
    func analysisDidUpdate(_ analysis: ExperimentAnalysis)
}

private let analysisQueue = DispatchQueue(label: "de.rwth-aachen.phyphox.analysis", attributes: [])

protocol ExperimentAnalysisTimestampSource: class {
    func getCurrentTimestamp() -> TimeInterval
}

final class ExperimentAnalysis {
    private let modules: [ExperimentAnalysisModule]
    
    private let sleep: Double
    private let dynamicSleep: DataBuffer?

    let inputBuffers: [String: DataBuffer]
    let outputBuffers: [String: DataBuffer]

    var running = false
    
    weak var timestampSource: ExperimentAnalysisTimestampSource?
    weak var delegate: ExperimentAnalysisDelegate?

    init(modules: [ExperimentAnalysisModule], sleep: Double, dynamicSleep: DataBuffer?) {
        self.modules = modules
        let inputBufferTuples = modules.flatMap({ $0.inputs.compactMap { input -> (String, DataBuffer)? in
            if let buffer = input.buffer {
                return (buffer.name, buffer)
            }
            else {
                return nil
            }
            }
        })

        inputBuffers = Dictionary(inputBufferTuples, uniquingKeysWith: { first, _ in first })

        let outputBufferTuples = modules.flatMap({ $0.outputs.compactMap { output -> (String, DataBuffer)? in
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
    
    private var busy = false
    private var requestedUpdateWhileBusy = false

    /**
     Schedules an update.
     */
    func setNeedsUpdate() {
        guard !busy else {
            requestedUpdateWhileBusy = true
            return
        }

        busy = true

        let delay = max(1/50.0, dynamicSleep?.last ?? sleep)

        after(delay) {
            if !self.running { //If the user stopped the experiment during sleep, we do not even want to start updating as we might end up overwriting the data the user wanted to pause on...
                self.busy = false
                return
            }

            self.delegate?.analysisWillUpdate(self)

            self.update {
                let didRequestUpdateWhileBusy = self.requestedUpdateWhileBusy

                self.requestedUpdateWhileBusy = false
                self.busy = false

                self.delegate?.analysisDidUpdate(self)

                if didRequestUpdateWhileBusy {
                    self.setNeedsUpdate()
                }
            }
        }
    }
    
    private func update(_ completion: @escaping () -> Void) {
        let c = modules.count - 1

        let timestamp = timestampSource?.getCurrentTimestamp() ?? 0.0

        for (i, analysis) in modules.enumerated() {
            analysisQueue.async(execute: {
                analysis.setNeedsUpdate(timestamp)
                if i == c {
                    mainThread {
                        completion()
                    }
                }
            })
        }
    }
}

extension ExperimentAnalysis: DataBufferObserver {
    func dataBufferUpdated(_ buffer: DataBuffer) {
        setNeedsUpdate()
    }
}
