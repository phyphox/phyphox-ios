//
//  TimerAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 02.04.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

final class TimerAnalysis: AutoClearingExperimentAnalysisModule {
    private static let outOutSlot = AnalysisIOSlot(name: "out", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let offset1970OutSlot = AnalysisIOSlot(name: "offset1970", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [], outputs: [Self.outOutSlot, Self.offset1970OutSlot])
    }
    let linearTime: Bool;
    
    private var outOutput: ExperimentAnalysisDataOutput?
    private var offset1970Output: ExperimentAnalysisDataOutput?
        
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        
        let attributes = additionalAttributes.attributes(keyedBy: String.self)

        linearTime = try attributes.optionalValue(for: "linearTime") ?? false
        
        let io = try Self.mapIO(inputs: inputs, outputs: outputs)
        outOutput = io.output(Self.outOutSlot)
        offset1970Output = io.output(Self.offset1970OutSlot)
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        if let output = outOutput {
            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.append(linearTime ? analysisLinearTime : analysisTime)
            }
        }
        if let output = offset1970Output {
            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.append(linearTime ? analysisLinearTimeOffset1970 : analysisTimeOffset1970)
            }
        }
    }
}
