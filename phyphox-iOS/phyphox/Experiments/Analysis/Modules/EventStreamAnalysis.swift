//
//  EventStreamAnalysis.swift
//  phyphox
//
//  Created by Sebastian Staacks on 07.05.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

final class EventStreamAnalysis: AutoClearingExperimentAnalysisModule {
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
    
    enum TriggerMode: String, LosslessStringConvertible, Equatable, CaseIterable {
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
        
        for input in inputs {
            if input.asString == "data" {
                switch input {
                case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                    dataIn = data
                case .value(value: _, usedAs: _):
                    break
                }
            }
            else if input.asString == "threshold" {
                thresholdIn = input
            }
            else if input.asString == "distance" {
                distanceIn = input
            }
            else if input.asString == "index" {
                indexIn = input
            }
            else if input.asString == "skip" {
                skipIn = input
            }
            else if input.asString == "last" {
                lastIn = input
            }
            else {
                print("Error: Invalid analysis input: \(String(describing: input.asString))")
            }
        }
        
        for output in outputs {
            if output.asString == "events" {
                eventsOut = output
            }
            else if output.asString == "index" {
                indexOut = output
            }
            else if output.asString == "skip" {
                skipOut = output
            }
            else if output.asString == "last" {
                lastOut = output
            }
            else {
                print("Error: Invalid analysis output: \(String(describing: output.asString))")
            }
        }
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        
        let inArray = dataIn.data
        
        let threshold = thresholdIn?.getSingleValue() ?? 0.0
        let distance = Int(distanceIn?.getSingleValue() ?? 0.0)
        let index = Int(indexIn?.getSingleValue() ?? 0.0)
        var skip = Int(skipIn?.getSingleValue() ?? 0.0)
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
