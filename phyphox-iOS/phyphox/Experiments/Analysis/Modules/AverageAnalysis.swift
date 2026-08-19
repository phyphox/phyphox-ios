//
//  AverageAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 06.10.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class AverageAnalysis: AutoClearingExperimentAnalysisModule {
    private static let bufferInSlot = AnalysisIOSlot(name: "buffer", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let averageOutSlot = AnalysisIOSlot(name: "average", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let stddevOutSlot = AnalysisIOSlot(name: "stddev", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [Self.bufferInSlot], outputs: [Self.averageOutSlot, Self.stddevOutSlot])
    }
    private var avgOutput: ExperimentAnalysisDataOutput?
    private var stdOutput: ExperimentAnalysisDataOutput?
    
    private let input: MutableDoubleArray
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        let io = try Self.mapIO(inputs: inputs, outputs: outputs)
        //Outputs map by the documented slot names "average" and "stddev"; an unnamed output
        //fills "average". The as attribute decides the slot, never document order - assigning
        //by position would silently swap the two values when they are written in reverse order.
        avgOutput = io.output(Self.averageOutSlot)
        stdOutput = io.output(Self.stddevOutSlot)

        guard let data = io.data(Self.bufferInSlot) else {
            throw SerializationError.genericError(message: "Average needs a buffer as input.")
        }
        input = data
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        
        var sum = 0.0
        var count = 0
        
        let x = input.data
        
        for v in x {
            if v.isFinite {
                sum += v
                count += 1
            }
        }
        //An empty or all-non-finite input is an intermediate error state: average delivers
        //single values, so each connected output receives NaN instead of nothing (the stddev
        //branch below yields NaN through its count < 2 case).
        let avg = count == 0 ? Double.nan : sum/Double(count)
        
        if let avgOutput = avgOutput {
            switch avgOutput {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray([avg])
            }
        }
        
        if let stdOutput = stdOutput {
            let std: Double
            if (count < 2) {
                std = Double.nan
            } else {
                sum = 0.0
                count = 0
                for v in x {
                    if v.isFinite {
                        sum += (v-avg)*(v-avg)
                        count += 1
                    }
                }
                std = sqrt(sum/(Double(count-1)))
            }

            switch stdOutput {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray([std])
            }
        }
    }
}
