//
//  MaxAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import Accelerate

final class MaxAnalysis: AutoClearingExperimentAnalysisModule {
    private static let xInSlot = AnalysisIOSlot(name: "x", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let yInSlot = AnalysisIOSlot(name: "y", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let thresholdInSlot = AnalysisIOSlot(name: "threshold", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let maxOutSlot = AnalysisIOSlot(name: "max", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let positionOutSlot = AnalysisIOSlot(name: "position", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [Self.xInSlot, Self.yInSlot, Self.thresholdInSlot], outputs: [Self.maxOutSlot, Self.positionOutSlot])
    }
    private var xIn: MutableDoubleArray?
    private var yIn: MutableDoubleArray!
    private var thresholdIn: ExperimentAnalysisDataInput?
    
    private var maxOut: ExperimentAnalysisDataOutput?
    private var positionOut: ExperimentAnalysisDataOutput?
    
    private var multiple: Bool
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        
        let attributes = additionalAttributes.attributes(keyedBy: String.self)

        multiple = try attributes.optionalValue(for: "multiple") ?? false

        let io = try Self.mapIO(inputs: inputs, outputs: outputs)
        xIn = io.data(Self.xInSlot)
        yIn = io.data(Self.yInSlot)
        thresholdIn = io.input(Self.thresholdInSlot)
        maxOut = io.output(Self.maxOutSlot)
        positionOut = io.output(Self.positionOutSlot)

        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        #if DEBUG_ANALYSIS
            if xIn != nil && thresholdIn != nil {
                debug_noteInputs(["valIn" : yIn, "posIn" : xIn, "thresholdIn" : thresholdIn])
            }
            else if xIn != nil {
                debug_noteInputs(["valIn" : yIn, "posIn" : xIn])
            }
            else if thresholdIn != nil {
                debug_noteInputs(["valIn" : yIn, "thresholdIn" : thresholdIn])
            }
            else {
                debug_noteInputs(["valIn" : yIn])
            }
        #endif
        
        let inArray = yIn.data
        
        if positionOut == nil && !multiple {
            var max = 0.0
            
            vDSP_maxvD(inArray, 1, &max, vDSP_Length(inArray.count))
                        
            if let maxOut = maxOut {
                switch maxOut {
                case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                    buffer.append(max)
                }
            }

            #if DEBUG_ANALYSIS
                debug_noteOutputs(max)
            #endif
            
        }
        else if multiple {
            var max = [Double]()
            var x = [Double]()
            let threshold = thresholdIn?.getSingleValue() ?? 0.0
            
            var thisMax = -Double.infinity
            var thisX = -Double.infinity
            for (i, v) in inArray.enumerated() {
                if v < threshold {
                    if (thisX.isFinite) {
                        max.append(thisMax)
                        x.append(thisX)
                        thisMax = -Double.infinity
                        thisX = -Double.infinity
                    }
                } else if v > thisMax {
                    thisMax = v
                    thisX = xIn?.data[i] ?? Double(i)
                }
            }
                        
            if let maxOut = maxOut {
                switch maxOut {
                case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                    buffer.appendFromArray(max)
                }
            }
            
            if let positionOut = positionOut {
                switch positionOut {
                case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                    buffer.appendFromArray(x)
                }
            }
        }
        else {
            var max = -Double.infinity
            var index: vDSP_Length = 0
            
            vDSP_maxviD(inArray, 1, &max, &index, vDSP_Length(inArray.count))
            
            let x: Double
            
            if let xIn = xIn, Int(index) < xIn.data.count {
                x = xIn.data[Int(index)]
            }
            else {
                x = Double(index)
            }
                        
            if let maxOut = maxOut {
                switch maxOut {
                case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                    buffer.append(max)
                }
            }
            
            if let positionOut = positionOut {
                switch positionOut {
                case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                    buffer.append(x)
                }
            }

            #if DEBUG_ANALYSIS
                debug_noteOutputs(["max" : max, "pos" : x])
            #endif
            
        }
    }
}
