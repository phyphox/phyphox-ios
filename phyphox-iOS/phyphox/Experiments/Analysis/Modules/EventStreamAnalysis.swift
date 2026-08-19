//
//  EventStreamAnalysis.swift
//  phyphox
//
//  Created by Sebastian Staacks on 07.05.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

final class EventStreamAnalysis: AutoClearingExperimentAnalysisModule {
    private static let dataInSlot = AnalysisIOSlot(name: "data", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let thresholdInSlot = AnalysisIOSlot(name: "threshold", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let distanceInSlot = AnalysisIOSlot(name: "distance", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let indexInSlot = AnalysisIOSlot(name: "index", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let skipInSlot = AnalysisIOSlot(name: "skip", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let lastInSlot = AnalysisIOSlot(name: "last", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let eventsOutSlot = AnalysisIOSlot(name: "events", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let indexOutSlot = AnalysisIOSlot(name: "index", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let skipOutSlot = AnalysisIOSlot(name: "skip", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let lastOutSlot = AnalysisIOSlot(name: "last", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [Self.dataInSlot, Self.thresholdInSlot, Self.distanceInSlot, Self.indexInSlot, Self.skipInSlot, Self.lastInSlot], outputs: [Self.eventsOutSlot, Self.indexOutSlot, Self.skipOutSlot, Self.lastOutSlot])
    }
    private var dataIn: MutableDoubleArray!
    private var thresholdIn: ExperimentAnalysisDataInput?
    private var distanceIn: ExperimentAnalysisDataInput?
    private var indexIn: ExperimentAnalysisDataInput?
    private var skipIn: ExperimentAnalysisDataInput?
    private var lastIn: ExperimentAnalysisDataInput?
    
    private var eventsOut: ExperimentAnalysisDataOutput?
    private var indexOut: ExperimentAnalysisDataOutput?
    private var skipOut: ExperimentAnalysisDataOutput?
    private var lastOut: ExperimentAnalysisDataOutput?
    
    enum TriggerMode: String, CaseInsensitiveAttributeDecodable, Equatable, CaseIterable {
        case above
        case below
        case aboveAbsolute
        case belowAbsolute
        case aboveDerivative
        case belowDerivative
        case aboveDerivativeAbsolute
        case belowDerivativeAbsolute
    }
    
    private var triggerMode: TriggerMode
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        
        let attributes = additionalAttributes.attributes(keyedBy: String.self)
        triggerMode = try attributes.optionalValue(for: "mode") ?? TriggerMode.above
        
        let io = try Self.mapIO(inputs: inputs, outputs: outputs)
        dataIn = io.data(Self.dataInSlot)
        thresholdIn = io.input(Self.thresholdInSlot)
        distanceIn = io.input(Self.distanceInSlot)
        indexIn = io.input(Self.indexInSlot)
        skipIn = io.input(Self.skipInSlot)
        lastIn = io.input(Self.lastInSlot)

        eventsOut = io.output(Self.eventsOutSlot)
        indexOut = io.output(Self.indexOutSlot)
        skipOut = io.output(Self.skipOutSlot)
        lastOut = io.output(Self.lastOutSlot)
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        
        let inArray = dataIn.data
        
        //A NaN threshold participates in the comparisons like any number (no trigger ever
        //fires); only an absent input or an empty buffer selects the default of 0.
        let threshold = thresholdIn?.getSingleValue() ?? 0.0

        //index/skip/last are the module's own state loop: absent inputs or empty buffers keep
        //the documented start defaults (0/0/NaN). A non-finite value reaching one of the Int
        //conversions is an error state yielding empty outputs - which resets the state loop to
        //its start defaults on the next run instead of trapping.
        let distanceValue = distanceIn?.getSingleValue() ?? 0.0
        let indexValue = indexIn?.getSingleValue() ?? 0.0
        let skipValue = skipIn?.getSingleValue() ?? 0.0
        guard distanceValue.isFinite && indexValue.isFinite && skipValue.isFinite
                && abs(distanceValue) < 9e18 && abs(indexValue) < 9e18 && abs(skipValue) < 9e18 else {
            return
        }
        let distance = Int(distanceValue)
        let index = Int(indexValue)
        var skip = Int(skipValue)
        var last = lastIn?.getSingleValue() ?? Double.nan
        
        let n = inArray.count
        
        var events: [Double] = []
        
        var i = 0
        while i < n {
            if skip > 0 {
                let steps: Int = min(skip, n-i)
                skip -= steps
                i += steps
                last = inArray[i-1]
                continue
            }
            let v = inArray[i]
            var triggered = false
            
            switch triggerMode {
            case .above:
                triggered = v > threshold
            case .below:
                triggered = v < threshold
            case .aboveAbsolute:
                triggered = abs(v) > threshold
            case .belowAbsolute:
                triggered = abs(v) < threshold
            case .aboveDerivative:
                triggered = v - last > threshold
            case .belowDerivative:
                triggered = v - last < threshold
            case .aboveDerivativeAbsolute:
                triggered = abs(v - last) > threshold
            case .belowDerivativeAbsolute:
                triggered = abs(v - last) < threshold
            }
            
            if triggered {
                events.append(Double(i+index))
                skip = distance
            }
            last = v
            i += 1
        }
        
        if let eventsOut = eventsOut {
            switch eventsOut {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(events)
            }
        }
        
        if let indexOut = indexOut {
            switch indexOut {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.append(Double(index+i))
            }
        }
        if let skipOut = skipOut {
            switch skipOut {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.append(Double(skip))
            }
        }
        if let lastOut = lastOut {
            switch lastOut {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.append(last)
            }
        }
    }
}
