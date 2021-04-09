//
//  ExperimentTimeReference.swift
//  phyphox
//
//  Created by Sebastian Staacks on 17.12.20.
//  Copyright © 2020 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentTimeReference: Equatable {
    static func == (lhs: ExperimentTimeReference, rhs: ExperimentTimeReference) -> Bool {
        return lhs.timeMappings == rhs.timeMappings
    }
        
    public enum TimeMappingEvent: String {
        case START
        case PAUSE
    }
    
    public struct TimeMapping: Equatable {
        public let event: TimeMappingEvent
        public let experimentTime: Double
        public let eventTime: TimeInterval
        public let systemTime: Date
        public var totalGap: Double? = nil
    }
    
    public var timeMappings: [TimeMapping] = []
    
    init() {
        reset()
    }
    
    public func reset() {
        timeMappings = []
    }
    
    public func registerEvent(event: TimeMappingEvent) {
        let eventTime = ProcessInfo.processInfo.systemUptime
        let systemTime = Date()
        
        if let last = timeMappings.last {
            switch last.event {
            case .START:
                if event != .PAUSE {
                    return
                }
                timeMappings.append(TimeMapping(event: event, experimentTime: getExperimentTimeFromEvent(eventTime: eventTime), eventTime: eventTime, systemTime: systemTime))
            case .PAUSE:
                if (event != .START) {
                    return
                }
                timeMappings.append(TimeMapping(event: event, experimentTime: last.experimentTime, eventTime: eventTime, systemTime: systemTime))
            }
        } else {
            if event != .START {
                return
            }
            timeMappings.append(TimeMapping(event: event, experimentTime: 0.0, eventTime: eventTime, systemTime: systemTime))
        }
    }
    
    public func getExperimentTimeFromEvent(eventTime: TimeInterval) -> Double {
        guard let last = timeMappings.last else {
            return 0.0
        }
        if last.event == .PAUSE {
            return last.experimentTime
        }
        return last.experimentTime + (eventTime - last.eventTime)
    }
    
    public func getExperimentTimeFromSystem(systemTime: Date) -> Double {
        guard let last = timeMappings.last else {
            return 0.0
        }
        if last.event == .PAUSE {
            return last.experimentTime
        }
        return last.experimentTime + (systemTime.timeIntervalSinceReferenceDate - last.systemTime.timeIntervalSinceReferenceDate)
    }
    
    public func getExperimentTime() -> Double {
        return getExperimentTimeFromEvent(eventTime: ProcessInfo.processInfo.systemUptime)
    }
    
    public func getLinearTime() -> Double {
        guard let first = timeMappings.first else {
            return 0.0
        }
        return Date().timeIntervalSinceReferenceDate - first.systemTime.timeIntervalSinceReferenceDate
    }
    
    public func getReferenceIndexFromExperimentTime(t: Double) -> Int {
        var i = 0
        while timeMappings.count > i+1 && timeMappings[i+1].experimentTime <= t {
            i += 1
        }
        return i
    }
    
    public func getReferenceIndexFromGappedExperimentTime(t: Double) -> Int {
        var i = 0
        while timeMappings.count > i+1 && timeMappings[i+1].experimentTime + getTotalGapByIndex(i: i) <= t {
            i += 1
        }
        return i
    }
    
    public func getReferenceIndexFromLinearTime(t: Double) -> Int {
        var i = 0
        while timeMappings.count > i+1 && timeMappings[i+1].systemTime.timeIntervalSinceReferenceDate - timeMappings[0].systemTime.timeIntervalSinceReferenceDate <= t {
            i += 1
        }
        return i
    }
    
    public func getSystemTimeReferenceByIndex(i: Int) -> Date {
        return timeMappings.count > i ? timeMappings[i].systemTime : Date()
    }
    
    public func getExperimentTimeReferenceByIndex(i: Int) -> Double {
        return timeMappings.count > i ? timeMappings[i].experimentTime : 0.0
    }
    
    public func getPausedByIndex(i: Int) -> Bool {
        return timeMappings.count > i ? timeMappings[i].event == .PAUSE : true
    }
    
    public func getTotalGapByIndex(i: Int) -> Double {
        guard let first = timeMappings.first, timeMappings.count > i else {
            return 0.0
        }
        if let gap = timeMappings[i].totalGap {
            return gap
        }
        var gap = 0.0
        var lastPause = first.systemTime
        for j in 0...i {
            if timeMappings[j].event == .PAUSE {
                lastPause = timeMappings[j].systemTime
            } else {
                gap += timeMappings[j].systemTime.timeIntervalSinceReferenceDate - lastPause.timeIntervalSinceReferenceDate
            }
        }
        timeMappings[i].totalGap = gap
        return gap
    }
    
}
