//
//  ThresholdAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

final class ThresholdAnalysis: AutoClearingExperimentAnalysisModule {
    private static let xInSlot = AnalysisIOSlot(name: "x", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let yInSlot = AnalysisIOSlot(name: "y", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let thresholdInSlot = AnalysisIOSlot(name: "threshold", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let positionOutSlot = AnalysisIOSlot(name: "position", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [Self.xInSlot, Self.yInSlot, Self.thresholdInSlot], outputs: [Self.positionOutSlot])
    }
    private let falling: Bool
    
    private var xIn: MutableDoubleArray?
    private var yIn: MutableDoubleArray!
    private var thresholdIn: ExperimentAnalysisDataInput?
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        let attributes = additionalAttributes.attributes(keyedBy: String.self)

        falling = try attributes.optionalValue(for: "falling") ?? false

        let io = try Self.mapIO(inputs: inputs, outputs: outputs)
        xIn = io.data(Self.xInSlot)
        yIn = io.data(Self.yInSlot)
        thresholdIn = io.input(Self.thresholdInSlot)

        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        var threshold = 0.0
        
        if let v = thresholdIn?.getSingleValue() {
            threshold = v.isNaN ? 0.0 : v
        }
        
        var x: Double = -1.0
        var onOppositeSide = false //We want to cross (!) the threshold. This becomes true, when we have a value on the "wrong" side of the threshold, so we can actually cross it
        
        for (i, value) in yIn.data.enumerated() {
            if let xIn = xIn, i < xIn.data.count {
                x = xIn.data[i]
            }
            else {
                x += 1.0
            }
            if (falling ? (value < threshold) : (value > threshold)) {
                if onOppositeSide {
                    break
                }
            } else {
                onOppositeSide = true
            }
        }
        
        for output in outputs {
            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.append(x)
            }
        }
    }
}
