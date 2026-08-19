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

    var multiple: Bool //internal for the unit tests, which cannot construct attributes

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

        //One comparison loop for both modes, matching Android: NaN never wins a comparison, so
        //non-finite values cannot leak into the result (vDSP_minvD would propagate them). An x
        //buffer shorter than y truncates processing to the common length; only an omitted x
        //input auto-generates indices.
        let count = xIn.map { Swift.min($0.data.count, inArray.count) } ?? inArray.count
        let threshold = thresholdIn?.getSingleValue() ?? 0.0

        var minValues = [Double]()
        var xValues = [Double]()

        var thisMin = Double.infinity
        var thisX = 0.0
        var found = false

        for i in 0..<count {
            let v = inArray[i]

            if multiple && v > threshold {
                if found {
                    minValues.append(thisMin)
                    xValues.append(thisX)
                    thisMin = Double.infinity
                    found = false
                }
            } else if v < thisMin {
                thisMin = v
                thisX = xIn?.data[i] ?? Double(i)
                found = true
            }
        }

        //Flush the final open set: the minimum is emitted even when the data ends inside a set
        //(matching Android). In single mode this emits the one global minimum.
        if found {
            minValues.append(thisMin)
            xValues.append(thisX)
        }

        //An empty or all-invalid input is an intermediate error state: NaN on each connected
        //output in single mode (min delivers single values there), empty outputs in multiple mode
        if !multiple && minValues.isEmpty {
            minValues = [Double.nan]
            xValues = [Double.nan]
        }

        if let minOut = minOut {
            switch minOut {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(minValues)
            }
        }

        if let positionOut = positionOut {
            switch positionOut {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(xValues)
            }
        }

        #if DEBUG_ANALYSIS
            debug_noteOutputs(["min" : minValues, "pos" : xValues])
        #endif
    }
}
