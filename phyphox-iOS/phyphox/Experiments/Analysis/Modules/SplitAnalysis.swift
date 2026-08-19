//
//  SplitAnalysis.swift
//  phyphox
//
//  Created by Sebastian Staacks on 07.05.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

final class SplitAnalysis: AutoClearingExperimentAnalysisModule {
    private static let dataInSlot = AnalysisIOSlot(name: "data", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let indexInSlot = AnalysisIOSlot(name: "index", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let overlapInSlot = AnalysisIOSlot(name: "overlap", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let out1OutSlot = AnalysisIOSlot(name: "out1", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let out2OutSlot = AnalysisIOSlot(name: "out2", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [Self.dataInSlot, Self.indexInSlot, Self.overlapInSlot], outputs: [Self.out1OutSlot, Self.out2OutSlot])
    }
    private var dataIn: MutableDoubleArray!
    private var indexIn: ExperimentAnalysisDataInput?
    private var overlapIn: ExperimentAnalysisDataInput?
    
    private var out1Out: ExperimentAnalysisDataOutput?
    private var out2Out: ExperimentAnalysisDataOutput?
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {

        let io = try Self.mapIO(inputs: inputs, outputs: outputs)
        dataIn = io.data(Self.dataInSlot)
        indexIn = io.input(Self.indexInSlot)
        overlapIn = io.input(Self.overlapInSlot)
        out1Out = io.output(Self.out1OutSlot)
        out2Out = io.output(Self.out2OutSlot)

        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {

        let inArray = dataIn.data

        //A present but non-finite index or overlap is an error state yielding empty outputs.
        //Finite values are clamped: negative and out-of-range positive indices are clamped into
        //range, and the overlap is clamped to the span that still affects the result - which
        //also keeps huge values out of the trapping Int conversion. Absent inputs keep the
        //defaults (index = input length, overlap = 0).
        let indexValue = indexIn?.getSingleValue() ?? Double(inArray.count)
        let overlapValue = overlapIn?.getSingleValue() ?? 0.0
        guard indexValue.isFinite && overlapValue.isFinite else {
            return
        }

        let count = Double(inArray.count)
        let index = Int(min(max(indexValue, 0), count))
        let overlap = Int(min(max(overlapValue, -(count + 1)), count + 1))

        var limit = min(index, inArray.count)
        if let out1Out = out1Out, limit > 0 {
            switch out1Out {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(Array(inArray[0..<limit]))
            }
        }
        
        limit = max(limit-overlap, 0)
        if let out2Out = out2Out, limit < inArray.count {
            switch out2Out {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(Array(inArray[limit..<inArray.count]))
            }
        }
        
    }
}
