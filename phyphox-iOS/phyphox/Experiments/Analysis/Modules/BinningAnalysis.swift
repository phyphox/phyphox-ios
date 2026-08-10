//
//  BinningAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 06.10.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class BinningAnalysis: AutoClearingExperimentAnalysisModule {
    private static let dataInSlot = AnalysisIOSlot(name: "in", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let x0InSlot = AnalysisIOSlot(name: "x0", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let dxInSlot = AnalysisIOSlot(name: "dx", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let binStartsOutSlot = AnalysisIOSlot(name: "binStarts", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let binCountsOutSlot = AnalysisIOSlot(name: "binCounts", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [Self.dataInSlot, Self.x0InSlot, Self.dxInSlot], outputs: [Self.binStartsOutSlot, Self.binCountsOutSlot])
    }
    private let inputBuffer: MutableDoubleArray
    private let x0Input: ExperimentAnalysisDataInput?
    private let dxInput: ExperimentAnalysisDataInput?
    
    private let binStartsOutput: ExperimentAnalysisDataOutput?
    private let binCountsOutput: ExperimentAnalysisDataOutput?
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        guard !inputs.isEmpty && !outputs.isEmpty else {
            throw SerializationError.genericError(message: "Binning analysis needs at least one input and ine output.")
        }

        let io = try Self.mapIO(inputs: inputs, outputs: outputs)

        guard let inputData = io.data(Self.dataInSlot) else {
            throw SerializationError.genericError(message: "Binning analysis needs a valid input designated as \"in\".")
        }
        inputBuffer = inputData

        x0Input = io.input(Self.x0InSlot)
        dxInput = io.input(Self.dxInSlot)
        binStartsOutput = io.output(Self.binStartsOutSlot)
        binCountsOutput = io.output(Self.binCountsOutSlot)
        
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
        
        for v in inputBuffer.data {
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
                
        if let binStartsOutput = binStartsOutput {
            switch binStartsOutput {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(binStarts)
            }
        }
        
        if let binCountsOutput = binCountsOutput {
            switch binCountsOutput {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(binCounts)
            }
        }
    }
}
