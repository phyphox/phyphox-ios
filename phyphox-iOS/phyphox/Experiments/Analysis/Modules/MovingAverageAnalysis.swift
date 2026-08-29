//
//  MovingAverageAnalysis.swift
//  phyphox
//
//  Created by Sebastian Staacks on 07.05.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

final class MovingAverageAnalysis: AutoClearingExperimentAnalysisModule {
    private static let dataInSlot = AnalysisIOSlot(name: "data", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let widthInSlot = AnalysisIOSlot(name: "width", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let dataOutSlot = AnalysisIOSlot(name: "data", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [Self.dataInSlot, Self.widthInSlot], outputs: [Self.dataOutSlot])
    }
    private var dataIn: MutableDoubleArray!
    private var widthIn: ExperimentAnalysisDataInput?
    
    private var dataOut: ExperimentAnalysisDataOutput?
    
    private let dropIncomplete: Bool
        
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        
        let attributes = additionalAttributes.attributes(keyedBy: String.self)
        dropIncomplete = try attributes.optionalValue(for: "dropIncomplete") ?? false

        let io = try Self.mapIO(inputs: inputs, outputs: outputs)
        dataIn = io.data(Self.dataInSlot)
        widthIn = io.input(Self.widthInSlot)
        dataOut = io.output(Self.dataOutSlot)

        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {

        let inArray = dataIn.data

        let width: Int
        if let widthValue = widthIn?.getSingleValue() {
            //A present but invalid width - non-finite or negative - is an error state yielding
            //empty output; it must not act as some substitute width.
            guard widthValue.isFinite && widthValue >= 0 && widthValue < 9e18 else {
                return
            }
            width = Int(widthValue)
        } else {
            //The documented default, also selected by an empty width buffer
            width = 10
        }

        let start = dropIncomplete ? width : 0
        if start >= inArray.count {
            return
        }

        var result: [Double] = []

        for i in start..<inArray.count {
            let substart = max(i-width, 0)
            //Skip non-finite values inside the window, aligning with average and binning; a
            //window without any finite value yields NaN
            var sum = 0.0
            var count = 0
            for j in substart...i {
                let v = inArray[j]
                if v.isFinite {
                    sum += v
                    count += 1
                }
            }
            result.append(sum / Double(count))
        }
        
        if let dataOut = dataOut {
            switch dataOut {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(result)
            }
        }
    }
}
