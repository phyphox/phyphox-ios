//
//  ThresholdAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

final class ThresholdAnalysis: AutoClearingExperimentAnalysisModule {
    private let falling: Bool
    
    private var xIn: MutableDoubleArray?
    private var yIn: MutableDoubleArray!
    private var thresholdIn: ExperimentAnalysisDataInput?
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        let attributes = additionalAttributes.attributes(keyedBy: String.self)

        falling = try attributes.optionalValue(for: "falling") ?? false

        for input in inputs {
            if input.asString == "threshold" {
                thresholdIn = input
            }
            else if input.asString == "y" {
                switch input {
                case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                    yIn = data
                case .value(value: _, usedAs: _):
                    break
                }
            }
            else if input.asString == "x" {
                switch input {
                case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                    xIn = data
                case .value(value: _, usedAs: _):
                    break
                }
            }
            else {
                print("Error: Invalid analysis input: \(String(describing: input.asString))")
            }
        }
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        var threshold = 0.0
        
        if let v = thresholdIn?.getSingleValue() {
            threshold = v
        }
        
        var x: Double?
        var onOppositeSide = false //We want to cross (!) the threshold. This becomes true, when we have a value on the "wrong" side of the threshold, so we can actually cross it
        
        for (i, value) in yIn.data.enumerated() {
            if (falling ? (value < threshold) : (value > threshold)) {
                if onOppositeSide {
                    if let xIn = xIn, i < xIn.data.count {
                        x = xIn.data[i]
                    }
                    else {
                        x = Double(i)
                    }
                    break
                }
            } else {
                onOppositeSide = true
            }
        }
        
        guard let xValue = x else {
            for output in outputs {
                switch output {
                case .buffer(buffer: let buffer, data: _, usedAs: _, append: let append):
                    if !append {
                        buffer.clear(reset: false)
                    }
                }
            }
            
            return
        }
        
        for output in outputs {
            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.append(xValue)
            }
        }
    }
}
