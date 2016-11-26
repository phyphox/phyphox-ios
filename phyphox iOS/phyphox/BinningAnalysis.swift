//
//  BinningAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 06.10.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class BinningAnalysis: ExperimentAnalysisModule {
    private var inInput: ExperimentAnalysisDataIO!
    private var x0Input: ExperimentAnalysisDataIO?
    private var dxInput: ExperimentAnalysisDataIO?
    
    private var binStartsOutput: ExperimentAnalysisDataIO?
    private var binCountsOutput: ExperimentAnalysisDataIO?
    
    override init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String : AnyObject]?) throws {
        if inputs.count == 0 || outputs.count == 0 {
            throw SerializationError.GenericError(message: "Binning analysis needs at least one input and ine output.")
        }
        var tIn: ExperimentAnalysisDataIO? = nil
        var tX0: ExperimentAnalysisDataIO? = nil
        var tDx: ExperimentAnalysisDataIO? = nil
        var tBinStarts: ExperimentAnalysisDataIO? = nil
        var tBinCounts: ExperimentAnalysisDataIO? = nil
        
        for input in inputs {
            if input.asString == "x0" {
                tX0 = input
            } else if input.asString == "dx" {
                tDx = input
            } else if tIn == nil {
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
        
        if tIn == nil {
            throw SerializationError.GenericError(message: "Binning analysis needs a valid input designated as \"in\".")
        }
        
        if tIn?.buffer == nil {
            throw SerializationError.GenericError(message: "Binning input \"in\" needs to be a buffer.")
        }
        
        inInput = tIn
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
        
        for v in inInput.buffer! {
            if !v.isFinite {
                continue
            }

            let binIndex = Int((v-x0)/dx)
            if binStarts.count == 0 {
                binStarts.append(x0+Double(binIndex)*dx)
                binCounts.append(1)
            } else {
                var firstBinIndex = Int(round((binStarts[0]-x0)/dx))
                while (binIndex > firstBinIndex + binStarts.count - 1) {
                    binStarts.append(x0 + Double(firstBinIndex+binStarts.count)*dx)
                    binCounts.append(0)
                }
                while binIndex < firstBinIndex {
                    binStarts.insert(x0+Double(firstBinIndex-1)*dx, atIndex: 0)
                    binCounts.insert(0, atIndex: 0)
                    firstBinIndex = Int(round((binStarts[0]-x0)/dx))
                }
                binCounts[binIndex-firstBinIndex] += 1
            }
        }
        
        if binStartsOutput != nil {
            if binStartsOutput!.clear {
                binStartsOutput!.buffer!.replaceValues(binStarts)
            }
            else {
                binStartsOutput!.buffer!.appendFromArray(binStarts)
            }
        }
        if binCountsOutput != nil {
            if binCountsOutput!.clear {
                binCountsOutput!.buffer!.replaceValues(binCounts)
            }
            else {
                binCountsOutput!.buffer!.appendFromArray(binCounts)
            }
        }
        

    }
}
