//
//  ExperimentTimeReference.swift
//  phyphox
//
//  Created by Sebastian Staacks on 17.12.20.
//  Copyright © 2020 RWTH Aachen. All rights reserved.
//

import Foundation

//The time reference maps experiment time to system time across start/pause/stop events. It is
//touched from many threads at once - the sensor and analysis threads timestamp data through it,
//the graph views read it to place data on a time axis, and the experiment lifecycle appends events
//on start/pause/stop. The mapping array was previously an unsynchronised `var`, so an append during
//teardown racing a read on the graph queue corrupted the array's storage and crashed in a Swift
//release (observed leaving a long-running experiment with the remote interface active). All access
//now goes through a serial queue: public methods lock once and delegate to private unlocked helpers
//(so cross-calls between them do not deadlock), and the public timeMappings accessor returns a
//consistent snapshot copy for external readers.
final class ExperimentTimeReference: Equatable {
    static func == (lhs: ExperimentTimeReference, rhs: ExperimentTimeReference) -> Bool {
        return lhs.timeMappings == rhs.timeMappings
    }

    public enum TimeMappingEvent: String {
        case START
        case PAUSE
        case CLEAR
    }

    public struct TimeMapping: Equatable {
        public let event: TimeMappingEvent
        public let experimentTime: Double
        public let eventTime: TimeInterval
        public let systemTime: Date
        public var totalGap: Double? = nil
    }

    private let queue = DispatchQueue(label: "de.rwth-aachen.phyphox.timereference")
    private var _timeMappings: [TimeMapping] = []

    //A consistent snapshot for external readers. Callers that iterate by index must bind this once
    //(let mappings = timeReference.timeMappings) rather than re-reading it inside the loop, as each
    //access returns a fresh copy.
    public var timeMappings: [TimeMapping] {
        return queue.sync { _timeMappings }
    }

    init() {
        reset()
    }

    public func reset() {
        queue.sync { _timeMappings = [] }
    }

    //Appends a pre-built mapping, used when loading a saved experiment state's recorded events.
    public func appendMapping(_ mapping: TimeMapping) {
        queue.sync { _timeMappings.append(mapping) }
    }

    public func registerEvent(event: TimeMappingEvent) {
        let eventTime = ProcessInfo.processInfo.systemUptime
        let systemTime = Date()

        queue.sync {
            if let last = _timeMappings.last {
                switch last.event {
                case .START:
                    if event == .START {
                        return
                    }
                    _timeMappings.append(TimeMapping(event: event, experimentTime: _getExperimentTimeFromEvent(eventTime: eventTime), eventTime: eventTime, systemTime: systemTime))
                case .PAUSE:
                    if (event == .PAUSE) {
                        return
                    }
                    _timeMappings.append(TimeMapping(event: event, experimentTime: last.experimentTime, eventTime: eventTime, systemTime: systemTime))
                default:
                    return
                }
            } else {
                if event != .START {
                    return
                }
                _timeMappings.append(TimeMapping(event: event, experimentTime: 0.0, eventTime: eventTime, systemTime: systemTime))
            }
        }
    }

    public func getExperimentTimeFromEvent(eventTime: TimeInterval) -> Double {
        return queue.sync { _getExperimentTimeFromEvent(eventTime: eventTime) }
    }

    private func _getExperimentTimeFromEvent(eventTime: TimeInterval) -> Double {
        guard let last = _timeMappings.last else {
            return 0.0
        }
        if last.event == .PAUSE {
            return last.experimentTime
        }
        return last.experimentTime + (eventTime - last.eventTime)
    }

    public func getExperimentTimeFromSystem(systemTime: Date) -> Double {
        return queue.sync {
            guard let last = _timeMappings.last else {
                return 0.0
            }
            if last.event == .PAUSE {
                return last.experimentTime
            }
            return last.experimentTime + (systemTime.timeIntervalSinceReferenceDate - last.systemTime.timeIntervalSinceReferenceDate)
        }
    }

    public func getExperimentTime() -> Double {
        let eventTime = ProcessInfo.processInfo.systemUptime
        return queue.sync { _getExperimentTimeFromEvent(eventTime: eventTime) }
    }

    public func getLinearTime() -> Double {
        return queue.sync {
            guard let first = _timeMappings.first else {
                return 0.0
            }
            return Date().timeIntervalSinceReferenceDate - first.systemTime.timeIntervalSinceReferenceDate
        }
    }

    public func getReferenceIndexFromExperimentTime(t: Double) -> Int {
        return queue.sync {
            var i = 0
            while _timeMappings.count > i+1 && _timeMappings[i+1].experimentTime <= t {
                i += 1
            }
            return i
        }
    }

    public func getReferenceIndexFromGappedExperimentTime(t: Double) -> Int {
        return queue.sync {
            var i = 0
            while _timeMappings.count > i+1 && _timeMappings[i+1].experimentTime + _getTotalGapByIndex(i: i) <= t {
                i += 1
            }
            return i
        }
    }

    public func getReferenceIndexFromLinearTime(t: Double) -> Int {
        return queue.sync {
            var i = 0
            while _timeMappings.count > i+1 && _timeMappings[i+1].systemTime.timeIntervalSinceReferenceDate - _timeMappings[0].systemTime.timeIntervalSinceReferenceDate <= t {
                i += 1
            }
            return i
        }
    }

    public func getSystemTimeReferenceByIndex(i: Int) -> Date {
        return queue.sync { _timeMappings.count > i ? _timeMappings[i].systemTime : Date() }
    }

    public func getExperimentTimeReferenceByIndex(i: Int) -> Double {
        return queue.sync { _timeMappings.count > i ? _timeMappings[i].experimentTime : 0.0 }
    }

    public func getPausedByIndex(i: Int) -> Bool {
        return queue.sync { _timeMappings.count > i ? _timeMappings[i].event == .PAUSE : true }
    }

    public func getTotalGapByIndex(i: Int) -> Double {
        return queue.sync { _getTotalGapByIndex(i: i) }
    }

    private func _getTotalGapByIndex(i: Int) -> Double {
        guard let first = _timeMappings.first, _timeMappings.count > i else {
            return 0.0
        }
        if let gap = _timeMappings[i].totalGap {
            return gap
        }
        var gap = 0.0
        var lastPause = first.systemTime
        for j in 0...i {
            if _timeMappings[j].event == .PAUSE {
                lastPause = _timeMappings[j].systemTime
            } else {
                gap += _timeMappings[j].systemTime.timeIntervalSinceReferenceDate - lastPause.timeIntervalSinceReferenceDate
            }
        }
        _timeMappings[i].totalGap = gap
        return gap
    }

}
