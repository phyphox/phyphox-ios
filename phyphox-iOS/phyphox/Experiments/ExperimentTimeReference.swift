//
//  ExperimentTimeReference.swift
//  phyphox
//
//  Created by Sebastian Staacks on 17.12.20.
//  Copyright © 2020 RWTH Aachen. All rights reserved.
//

import Foundation

//Maps experiment time to system time across start/pause/stop. Accessed from many threads, so all access goes through a
//lock: public methods lock once and delegate to private unlocked helpers (no deadlock on cross-calls). A plain lock rather
//than a serial dispatch queue: the graph views query this once per data point from their own queues, and on iOS 26.6 the
//contended dispatch_sync waiter handoff trapped inside libdispatch (the top new crash of 1.2.1).
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

    private let lock = NSLock()
    
    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
    private var _timeMappings: [TimeMapping] = []

    //Snapshot copy; bind it once before iterating by index, each access returns a fresh copy
    public var timeMappings: [TimeMapping] {
        return locked { _timeMappings }
    }

    init() {
        reset()
    }

    public func reset() {
        locked { _timeMappings = [] }
    }

    //Used when loading a saved state's recorded events
    public func appendMapping(_ mapping: TimeMapping) {
        locked { _timeMappings.append(mapping) }
    }

    public func registerEvent(event: TimeMappingEvent) {
        let eventTime = ProcessInfo.processInfo.systemUptime
        let systemTime = Date()

        locked {
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
        return locked { _getExperimentTimeFromEvent(eventTime: eventTime) }
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
        return locked {
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
        return locked { _getExperimentTimeFromEvent(eventTime: eventTime) }
    }

    public func getLinearTime() -> Double {
        return locked {
            guard let first = _timeMappings.first else {
                return 0.0
            }
            return Date().timeIntervalSinceReferenceDate - first.systemTime.timeIntervalSinceReferenceDate
        }
    }

    public func getReferenceIndexFromExperimentTime(t: Double) -> Int {
        return locked {
            var i = 0
            while _timeMappings.count > i+1 && _timeMappings[i+1].experimentTime <= t {
                i += 1
            }
            return i
        }
    }

    public func getReferenceIndexFromGappedExperimentTime(t: Double) -> Int {
        return locked {
            var i = 0
            while _timeMappings.count > i+1 && _timeMappings[i+1].experimentTime + _getTotalGapByIndex(i: i) <= t {
                i += 1
            }
            return i
        }
    }

    public func getReferenceIndexFromLinearTime(t: Double) -> Int {
        return locked {
            var i = 0
            while _timeMappings.count > i+1 && _timeMappings[i+1].systemTime.timeIntervalSinceReferenceDate - _timeMappings[0].systemTime.timeIntervalSinceReferenceDate <= t {
                i += 1
            }
            return i
        }
    }

    public func getSystemTimeReferenceByIndex(i: Int) -> Date {
        return locked { _timeMappings.count > i ? _timeMappings[i].systemTime : Date() }
    }

    public func getExperimentTimeReferenceByIndex(i: Int) -> Double {
        return locked { _timeMappings.count > i ? _timeMappings[i].experimentTime : 0.0 }
    }

    public func getPausedByIndex(i: Int) -> Bool {
        return locked { _timeMappings.count > i ? _timeMappings[i].event == .PAUSE : true }
    }

    public func getTotalGapByIndex(i: Int) -> Double {
        return locked { _getTotalGapByIndex(i: i) }
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
