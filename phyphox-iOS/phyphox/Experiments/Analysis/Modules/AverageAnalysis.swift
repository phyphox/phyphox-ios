//
//  AverageAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 06.10.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class AverageAnalysis: ExperimentAnalysisModule {
    private var avgOutput: ExperimentAnalysisDataIO?
    private var stdOutput: ExperimentAnalysisDataIO?
    
    private let input: DataBuffer
    
    required init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: AttributeContainer) throws {
        var avg: ExperimentAnalysisDataIO? = nil
        var std: ExperimentAnalysisDataIO? = nil
        for output in outputs {
            if output.asString == "std" || avg != nil {
                std = output
            }
            else {
                avg = output
            }
        }
        avgOutput = avg
        stdOutput = std

        guard let firstInput = inputs.first else {
            throw SerializationError.genericError(message: "Average needs a buffer as input.")
        }

        switch firstInput {
        case .buffer(buffer: let buffer, usedAs: _, clear: _):
            input = buffer
        case .value(value: _, usedAs: _):
            throw SerializationError.genericError(message: "Average needs a buffer as input.")
        }
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        
        var sum = 0.0
        var count = 0
        
        let x = input.toArray()
        
        for v in x {
            if v.isFinite {
                sum += v
                count += 1
            }
        }
        if count == 0 {
            return
        }

        let avg = sum/Double(count)
        
        beforeWrite()

        if let avgOutput = avgOutput {
            switch avgOutput {
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues([avg])
                }
                else {
                    buffer.appendFromArray([avg])
                }
            case .value(value: _, usedAs: _):
                break
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
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues([std])
                }
                else {
                    buffer.appendFromArray([std])
                }
            case .value(value: _, usedAs: _):
                break
            }
        }
    }
}
