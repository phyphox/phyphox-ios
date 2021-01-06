//
//  TimerAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 02.04.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

final class TimerAnalysis: ExperimentAnalysisModule {
    let linearTime: Bool;
    
    private var outOutput: ExperimentAnalysisDataIO?
    private var offset1970Output: ExperimentAnalysisDataIO?
        
    required init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: AttributeContainer) throws {
        
        let attributes = additionalAttributes.attributes(keyedBy: String.self)

        linearTime = try attributes.optionalValue(for: "linearTime") ?? false
        
        var out: ExperimentAnalysisDataIO? = nil
        var offset1970: ExperimentAnalysisDataIO? = nil
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
        beforeWrite()
        if let output = outOutput {
            switch output {
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues([linearTime ? analysisLinearTime : analysisTime])
                }
                else {
                    buffer.append(linearTime ? analysisLinearTime : analysisTime)
                }
            case .value(value: _, usedAs: _):
                break
            }
        }
        if let output = offset1970Output {
            switch output {
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues([linearTime ? analysisLinearTimeOffset1970 : analysisTimeOffset1970])
                }
                else {
                    buffer.append(linearTime ? analysisLinearTimeOffset1970 : analysisTimeOffset1970)
                }
            case .value(value: _, usedAs: _):
                break
            }
        }
    }
}
