//
//  ReduceAnalysis.swift
//  phyphox
//
//  Created by Sebastian Staacks on 03.04.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation

final class ReduceAnalysis: AutoClearingExperimentAnalysisModule {
    private static let factorInSlot = AnalysisIOSlot(name: "factor", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let xInSlot = AnalysisIOSlot(name: "x", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let yInSlot = AnalysisIOSlot(name: "y", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let xOutSlot = AnalysisIOSlot(name: "x", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let yOutSlot = AnalysisIOSlot(name: "y", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [Self.factorInSlot, Self.xInSlot, Self.yInSlot], outputs: [Self.xOutSlot, Self.yOutSlot])
    }
    //internal for the unit tests, which cannot construct attributes
    var averageX = false
    var averageY = false
    var sumY = false
    
    private var factor: ExperimentAnalysisDataInput? = nil
    private var inX: MutableDoubleArray? = nil
    private var inY: MutableDoubleArray? = nil
    
    private var outX: ExperimentAnalysisDataOutput? = nil
    private var outY: ExperimentAnalysisDataOutput? = nil
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        
        let attributes = additionalAttributes.attributes(keyedBy: String.self)
        averageX = try attributes.optionalValue(for: "averageX") ?? false
        averageY = try attributes.optionalValue(for: "averageY") ?? false
        sumY = try attributes.optionalValue(for: "sumY") ?? false
        
        let io = try Self.mapIO(inputs: inputs, outputs: outputs)
        factor = io.input(Self.factorInSlot)
        inX = io.data(Self.xInSlot)
        inY = io.data(Self.yInSlot)

        if (outputs.count < 1) {
            throw SerializationError.genericError(message: "Error: No output for reduce-module specified.")
        }

        outX = io.output(Self.xOutSlot)
        outY = io.output(Self.yOutSlot)
        
        if factor == nil {
            throw SerializationError.genericError(message: "Error: Reduce module requires input \"factor\".")
        }
        
        if inX == nil {
            throw SerializationError.genericError(message: "Error: Reduce module requires input \"x\".")
        }
        
        if outX == nil {
            throw SerializationError.genericError(message: "Error: Reduce module requires output \"x\".")
        }
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        guard let fac = factor?.getSingleValue() else {
            return
        }
        
        //A non-finite factor is an error state yielding empty outputs (and must not reach the
        //Int conversions below)
        guard fac.isFinite else {
            return
        }

        let x = inX!.data
        let y = inY?.data

        //Processing truncates to the shortest present buffer; only an absent y input keeps
        //processing all of x (with 0 as the y contribution)
        let count = y.map { Swift.min(x.count, $0.count) } ?? x.count

        var resX = [Double]()
        var resY = [Double]()

        if fac > 1 {
            guard fac < 9e18 else {
                return
            }
            let ifac = Int(round(fac))
            var index = 0
            var i = 0
            while index < count {
                var newX = 0.0
                var newY = 0.0
                var used = 0
                for j in 0..<ifac {
                    index = i*ifac+j
                    if index >= count {
                        break
                    }
                    used += 1
                    if j == 0 {
                        newX = x[index]
                        newY = y != nil ? y![index] : 0.0
                    } else  {
                        if sumY || averageY {
                            newY += y != nil ? y![index] : 0.0
                        }
                        if averageX {
                            newX += x[index]
                        }
                    }
                }
                //The incomplete final chunk is averaged over the number of values actually
                //summed, not the nominal factor
                if averageX {
                    newX /= Double(used)
                }
                if averageY {
                    newY /= Double(used)
                }

                resX.append(newX)
                resY.append(newY)
                i += 1
                index = i*ifac
            }
        } else if fac > 0 {
            let upFactor = round(1.0/fac)
            guard upFactor < 9e18 else {
                return
            }
            let ifac = Int(upFactor)
            for i in 0..<count {
                for _ in 0..<ifac {
                    resX.append(x[i])
                    resY.append(y != nil ? y![i] : 0.0)
                }
            }
        }
                
        switch outX! {
        case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
            buffer.appendFromArray(resX)
        }
        
        if let yOut = outY {
            switch yOut {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(resY)
            }
        }

    }
}
