//
//  InterpolateAnalysis.swift
//  phyphox
//
//  Created by Sebastian Staacks on 22.05.20.
//  Copyright © 2020 RWTH Aachen. All rights reserved.
//

import Foundation

final class InterpolateAnalysis: AutoClearingExperimentAnalysisModule {
    private static let xInSlot = AnalysisIOSlot(name: "x", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let yInSlot = AnalysisIOSlot(name: "y", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let xiInSlot = AnalysisIOSlot(name: "xi", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let outOutSlot = AnalysisIOSlot(name: "out", asRequired: false, repeatOffset: 0, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 0)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [Self.xInSlot, Self.yInSlot, Self.xiInSlot], outputs: [Self.outOutSlot])
    }
    enum InterpolationMethod: String, CaseInsensitiveAttributeDecodable, CaseIterable {
        case previous
        case next
        case nearest
        case linear
    }
    
    let method: InterpolationMethod
    
    private var xIn: MutableDoubleArray?
    private var yIn: MutableDoubleArray?
    private var xLocIn: MutableDoubleArray?
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        
        let attributes = additionalAttributes.attributes(keyedBy: String.self)

        method = try attributes.optionalValue(for: "method") ?? .linear

        let io = try Self.mapIO(inputs: inputs, outputs: outputs)
        xIn = io.data(Self.xInSlot)
        yIn = io.data(Self.yInSlot)
        xLocIn = io.data(Self.xiInSlot)

        if (xIn == nil) {
            throw SerializationError.genericError(message: "Error: No input for x provided to interpolate module.")
        }
        
        if (yIn == nil) {
            throw SerializationError.genericError(message: "Error: No input for y provided to interpolate module.")
        }
        
        if (xLocIn == nil) {
            throw SerializationError.genericError(message: "Error: No input for xi provided to interpolate module.")
        }
            
        if (outputs.count < 1) {
            throw SerializationError.genericError(message: "Error: No output for interpolate module specified.")
        }
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        guard let x = xIn?.data else {
            return
        }
        guard let y = yIn?.data else {
            return
        }
        guard let xOut = xLocIn?.data else {
            return
        }
        
        let incount = min(x.count, y.count)

        var result: [Double] = []
        
        var j = 0
        for xi in xOut {
            if incount == 0 {
                result.append(Double.nan)
                continue
            } else if incount == 1 {
                result.append(y[0])
                continue
            }
                
            while (j < incount && x[j] < xi) {
                j += 1
            }
            
            if (j == 0) {
                result.append(y[j])
                continue
            } else if (j == incount) {
                result.append(y[incount-1])
                continue
            } else if x[j] == xi {
                result.append(y[j])
                continue
            }
            
            let yi: Double
            switch method {
            case .previous:
                yi = y[j-1]
            case .next:
                yi = y[j]
            case .nearest:
                yi = (xi - x[j-1] < x[j] - xi) ? y[j-1] : y[j]
            case .linear:
                yi = y[j-1] + (y[j]-y[j-1])*(xi-x[j-1])/(x[j]-x[j-1])
            }
            
            result.append(yi)

        }
        
        switch outputs[0] {
        case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
            buffer.appendFromArray(result)
        }
    }
}
