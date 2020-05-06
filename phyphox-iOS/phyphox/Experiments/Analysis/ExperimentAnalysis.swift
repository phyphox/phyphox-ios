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

protocol ExperimentAnalysisTimestampSource: class {
    func getCurrentTimestamp() -> TimeInterval
}

final class ExperimentAnalysis {
    private let modules: [ExperimentAnalysisModule]

    private let sleep: Double
    private let dynamicSleep: DataBuffer?

    var running = false
    
    weak var timestampSource: ExperimentAnalysisTimestampSource?
    weak var delegate: ExperimentAnalysisDelegate?

    public var queue: DispatchQueue?
    
    init(modules: [ExperimentAnalysisModule], sleep: Double, dynamicSleep: DataBuffer?) {
        self.modules = modules
        self.sleep = sleep
        self.dynamicSleep = dynamicSleep

        //We subscribe to all buffers which are used as an input BEFORE another analysis module has written to them. This in particular not only includes inputs from sensors, Bluetooth inputs and similar, but also buffers that may have been written at the end of the previous analysis run.
        var internallyUpdatedBuffers: Set<String> = []
        for module in modules {
            for input in module.inputs {
                switch input {
                case .buffer(buffer: let buffer, usedAs: _, clear: _):
                    if !(internallyUpdatedBuffers.contains(buffer.name)) {
                        buffer.addObserver(self, alwaysNotify: false)
                    }
                case .value(value: _, usedAs: _):
                    continue
                }
            }
            for output in module.outputs {
                switch output {
                case .buffer(buffer: let buffer, usedAs: _, clear: _):
                    internallyUpdatedBuffers.insert(buffer.name)
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
            queue?.async(execute: {
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

extension ExperimentAnalysis: Equatable {
    static func ==(lhs: ExperimentAnalysis, rhs: ExperimentAnalysis) -> Bool {
        return lhs.sleep == rhs.sleep &&
            lhs.dynamicSleep == rhs.dynamicSleep &&
            lhs.modules == rhs.modules
    }
}
