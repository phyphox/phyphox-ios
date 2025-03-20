//
//  TimerAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 02.04.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

final class TimerAnalysis: AutoClearingExperimentAnalysisModule {
    let linearTime: Bool;
    
    private var outOutput: ExperimentAnalysisDataOutput?
    private var offset1970Output: ExperimentAnalysisDataOutput?
        
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        
        let attributes = additionalAttributes.attributes(keyedBy: String.self)

        linearTime = try attributes.optionalValue(for: "linearTime") ?? false
        
        var out: ExperimentAnalysisDataOutput? = nil
        var offset1970: ExperimentAnalysisDataOutput? = nil
        for output in outputs {
            if output.asString == "offset1970" || out != nil {
                offset1970 = output
            }
            else {
                out = output
            }
        }
        outOutput = out
        offset1970Output = offset1970
        
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
