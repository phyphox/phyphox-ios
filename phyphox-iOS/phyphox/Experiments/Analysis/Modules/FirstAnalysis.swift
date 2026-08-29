//
//  FirstAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

final class FirstAnalysis: AutoClearingExperimentAnalysisModule {
    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [
            AnalysisIOSlot(name: "value", asRequired: false, repeatOffset: 0, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 0)
        ], outputs: [
            AnalysisIOSlot(name: "first", asRequired: false, repeatOffset: 0, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 0)
        ])
    }
    override func update() {
        //Output i receives the first value of input i; an empty input skips only its own pair
        //(matching Android) - never broadcast all first values to every output
        for (i, output) in outputs.enumerated() {
            guard i < inputs.count else { break }

            let first: Double?
            switch inputs[i] {
            case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                first = data.data.first
            case .value(value: _, usedAs: _):
                first = nil
            }

            guard let value = first else { continue }

            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.append(value)
            }
        }
    }
}
