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

    //The per-index queries take the lock once each. Hot loops (the graph views ask per data point) should take one
    //snapshot via timeMappings and use the same queries on the array instead.
    public func getReferenceIndexFromExperimentTime(t: Double) -> Int {
        return locked { _timeMappings.referenceIndex(fromExperimentTime: t) }
    }

    public func getReferenceIndexFromGappedExperimentTime(t: Double) -> Int {
        return locked { _timeMappings.referenceIndex(fromGappedExperimentTime: t) }
    }

    public func getReferenceIndexFromLinearTime(t: Double) -> Int {
        return locked { _timeMappings.referenceIndex(fromLinearTime: t) }
    }

    public func getSystemTimeReferenceByIndex(i: Int) -> Date {
        return locked { _timeMappings.systemTimeReference(byIndex: i) }
    }

    public func getExperimentTimeReferenceByIndex(i: Int) -> Double {
        return locked { _timeMappings.experimentTimeReference(byIndex: i) }
    }

    public func getPausedByIndex(i: Int) -> Bool {
        return locked { _timeMappings.paused(byIndex: i) }
    }

    public func getTotalGapByIndex(i: Int) -> Double {
        return locked { _getTotalGapByIndex(i: i) }
    }

    //Caches the gap in the mapping, so later snapshots carry it
    private func _getTotalGapByIndex(i: Int) -> Double {
        guard _timeMappings.count > i else {
            return 0.0
        }
        if let gap = _timeMappings[i].totalGap {
            return gap
        }
        let gap = _timeMappings.totalGap(byIndex: i)
        _timeMappings[i].totalGap = gap
        return gap
    }

}

//The queries on a snapshot of the mappings, lock-free. The instance methods above are the same computations under the lock.
extension Array where Element == ExperimentTimeReference.TimeMapping {
    func referenceIndex(fromExperimentTime t: Double) -> Int {
        var i = 0
        while count > i+1 && self[i+1].experimentTime <= t {
            i += 1
        }
        return i
    }

    func referenceIndex(fromGappedExperimentTime t: Double) -> Int {
        var i = 0
        while count > i+1 && self[i+1].experimentTime + totalGap(byIndex: i) <= t {
            i += 1
        }
        return i
    }

    func referenceIndex(fromLinearTime t: Double) -> Int {
        var i = 0
        while count > i+1 && self[i+1].systemTime.timeIntervalSinceReferenceDate - self[0].systemTime.timeIntervalSinceReferenceDate <= t {
            i += 1
        }
        return i
    }

    func systemTimeReference(byIndex i: Int) -> Date {
        return count > i ? self[i].systemTime : Date()
    }

    func experimentTimeReference(byIndex i: Int) -> Double {
        return count > i ? self[i].experimentTime : 0.0
    }

    func paused(byIndex i: Int) -> Bool {
        return count > i ? self[i].event == .PAUSE : true
    }

    func totalGap(byIndex i: Int) -> Double {
        guard let first = first, count > i else {
            return 0.0
        }
        if let gap = self[i].totalGap {
            return gap
        }
        var gap = 0.0
        var lastPause = first.systemTime
        for j in 0...i {
            if self[j].event == .PAUSE {
                lastPause = self[j].systemTime
            } else {
                gap += self[j].systemTime.timeIntervalSinceReferenceDate - lastPause.timeIntervalSinceReferenceDate
            }
        }
        return gap
    }
}
