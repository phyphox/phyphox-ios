//
//  MinAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 02.05.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//


import Foundation
import Accelerate

final class MinAnalysis: AutoClearingExperimentAnalysisModule {
    private static let xInSlot = AnalysisIOSlot(name: "x", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let yInSlot = AnalysisIOSlot(name: "y", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let thresholdInSlot = AnalysisIOSlot(name: "threshold", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let minOutSlot = AnalysisIOSlot(name: "min", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let positionOutSlot = AnalysisIOSlot(name: "position", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [Self.xInSlot, Self.yInSlot, Self.thresholdInSlot], outputs: [Self.minOutSlot, Self.positionOutSlot])
    }

    private var xIn: MutableDoubleArray?
    private var yIn: MutableDoubleArray!
    private var thresholdIn: ExperimentAnalysisDataInput?

    private var minOut: ExperimentAnalysisDataOutput?
    private var positionOut: ExperimentAnalysisDataOutput?

    private var multiple: Bool

    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        let attributes = additionalAttributes.attributes(keyedBy: String.self)

        multiple = try attributes.optionalValue(for: "multiple") ?? false

        let io = try Self.mapIO(inputs: inputs, outputs: outputs)
        xIn = io.data(Self.xInSlot)
        yIn = io.data(Self.yInSlot)
        thresholdIn = io.input(Self.thresholdInSlot)
        minOut = io.output(Self.minOutSlot)
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
            var min = 0.0
            
            vDSP_minvD(inArray, 1, &min, vDSP_Length(inArray.count))
                        
            if let minOut = minOut {
                switch minOut {
                case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                    buffer.append(min)
                }
            }
            #if DEBUG_ANALYSIS
                debug_noteOutputs(min)
            #endif
            
        }
        else if multiple {
            var min = [Double]()
            var x = [Double]()
            let threshold = thresholdIn?.getSingleValue() ?? 0.0
            
            var thisMin = Double.infinity
            var thisX = -Double.infinity
            for (i, v) in inArray.enumerated() {
                if v > threshold {
                    if (thisX.isFinite) {
                        min.append(thisMin)
                        x.append(thisX)
                        thisMin = Double.infinity
                        thisX = -Double.infinity
                    }
                } else if v < thisMin {
                    thisMin = v
                    thisX = xIn?.data[i] ?? Double(i)
                }
            }
                        
            if let minOut = minOut {
                switch minOut {
                case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                    buffer.appendFromArray(min)
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
            var min = -Double.infinity
            var index: vDSP_Length = 0
            
            vDSP_minviD(inArray, 1, &min, &index, vDSP_Length(inArray.count))
            
            let x: Double
            
            if xIn != nil {
                x = xIn!.data[Int(index)]
            }
            else {
                x = Double(index)
            }
                        
            if let minOut = minOut {
                switch minOut {
                case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                    buffer.append(min)
                }
            }
            
            if let positionOut = positionOut {
                switch positionOut {
                case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                    buffer.append(x)
                }
            }

            #if DEBUG_ANALYSIS
                debug_noteOutputs(["min" : min, "pos" : x])
            #endif
            
        }
    }
}
