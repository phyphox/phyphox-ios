//
//  BinningAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 06.10.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class BinningAnalysis: ExperimentAnalysisModule {
    private let inputBuffer: DataBuffer
    private let x0Input: ExperimentAnalysisDataIO?
    private let dxInput: ExperimentAnalysisDataIO?
    
    private let binStartsOutput: ExperimentAnalysisDataIO?
    private let binCountsOutput: ExperimentAnalysisDataIO?
    
    required init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: AttributeContainer) throws {
        guard !inputs.isEmpty && !outputs.isEmpty else {
            throw SerializationError.genericError(message: "Binning analysis needs at least one input and ine output.")
        }

        var tIn: ExperimentAnalysisDataIO?
        var tX0: ExperimentAnalysisDataIO?
        var tDx: ExperimentAnalysisDataIO?
        var tBinStarts: ExperimentAnalysisDataIO?
        var tBinCounts: ExperimentAnalysisDataIO?
        
        for input in inputs {
            if input.asString == "x0" {
                tX0 = input
            }
            else if input.asString == "dx" {
                tDx = input
            }
            else if tIn == nil {
                tIn = input
            }
        }
        
        for output in outputs {
            if output.asString == "binCounts" || tBinStarts != nil {
                tBinCounts = output
            }
            else {
                tBinStarts = output
            }
        }
        
        guard let tInput = tIn else {
            throw SerializationError.genericError(message: "Binning analysis needs a valid input designated as \"in\".")
        }

        switch tInput {
        case .buffer(buffer: let buffer, usedAs: _, clear: _):
            inputBuffer = buffer
        case .value(value: _, usedAs: _):
            throw SerializationError.genericError(message: "Binning input \"in\" needs to be a buffer.")
        }

        x0Input = tX0
        dxInput = tDx
        binStartsOutput = tBinStarts
        binCountsOutput = tBinCounts
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        let x0 = x0Input?.getSingleValue() ?? 0.0
        var dx = dxInput?.getSingleValue() ?? 1.0
        if dx == 0.0 {
            dx = 1.0
        }
        
        var binStarts = [Double]()
        var binCounts = [Double]()
        
        for v in inputBuffer {
            if !v.isFinite {
                continue
            }

            let binIndex = Int((v-x0)/dx)
            if binStarts.count == 0 {
                binStarts.append(x0+Double(binIndex)*dx)
                binCounts.append(1)
            }
            else {
                var firstBinIndex = Int(round((binStarts[0]-x0)/dx))
                while binIndex > firstBinIndex + binStarts.count - 1 {
                    binStarts.append(x0 + Double(firstBinIndex+binStarts.count)*dx)
                    binCounts.append(0)
                }
                while binIndex < firstBinIndex {
                    binStarts.insert(x0+Double(firstBinIndex-1)*dx, at: 0)
                    binCounts.insert(0, at: 0)
                    firstBinIndex = Int(round((binStarts[0]-x0)/dx))
                }
                binCounts[binIndex-firstBinIndex] += 1
            }
        }
        
        beforeWrite()
        
        if let binStartsOutput = binStartsOutput {
            switch binStartsOutput {
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues(binStarts)
                }
                else {
                    buffer.appendFromArray(binStarts)
                }
            case .value(value: _, usedAs: _):
                break
            }
        }
        
        if let binCountsOutput = binCountsOutput {
            switch binCountsOutput {
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues(binCounts)
                }
                else {
                    buffer.appendFromArray(binCounts)
                }
            case .value(value: _, usedAs: _):
                break
            }
        }
    }
}
