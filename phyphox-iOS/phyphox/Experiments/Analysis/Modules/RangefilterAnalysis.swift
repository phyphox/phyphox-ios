//
//  RangefilterAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

final class RangefilterAnalysis: AutoClearingExperimentAnalysisModule {
    private static let inInSlot = AnalysisIOSlot(name: "in", asRequired: false, repeatOffset: 0, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 0)
    private static let minInSlot = AnalysisIOSlot(name: "min", asRequired: true, repeatOffset: 1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 0)
    private static let maxInSlot = AnalysisIOSlot(name: "max", asRequired: true, repeatOffset: 2, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 0)
    private static let outOutSlot = AnalysisIOSlot(name: "out", asRequired: false, repeatOffset: 0, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 0)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [Self.inInSlot, Self.minInSlot, Self.maxInSlot], outputs: [Self.outOutSlot])
    }
    private final class Range: CustomStringConvertible {
        let min: Double
        let max: Double

        init(min: Double, max: Double) {
            self.min = min
            self.max = max
        }

        var description: String {
            get {
                return "Range <\(Unmanaged.passUnretained(self).toOpaque())> (\(min), \(max))"
            }
        }
    }

    override func update() {
        var groups: [(Range, MutableDoubleArray)] = []

        var currentIn: MutableDoubleArray? = nil
        var currentMax: Double = Double.infinity
        var currentMin: Double = -Double.infinity

        for input in inputs {
            if input.used(as: "min") {
                if let v = input.getSingleValue() {
                    currentMin = v
                }
            }
            else if input.used(as: "max") {
                if let v = input.getSingleValue() {
                    currentMax = v
                }
            }
            else {
                switch input {
                case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                    if let currentInput = currentIn {
                        groups.append((Range(min: currentMin, max: currentMax), currentInput))
                        currentMax = Double.infinity
                        currentMin = -Double.infinity
                    }
                    //A min/max given before the first in binds to the first group (matching
                    //Android), so the accumulated bounds are only reset after a flush
                    currentIn = data
                case .value(value: _, usedAs: _):
                    break
                }
            }
        }

        if let currentIn = currentIn {
            groups.append((Range(min: currentMin, max: currentMax), currentIn))
        }

        #if DEBUG_ANALYSIS
            debug_noteInputs(groups.map({ (element) -> [Range: DataBuffer] in
                return [element.0 : element.1]
            }))
        #endif

        //Strictly row-wise filtering, matching Android: a row is dropped for ALL outputs when
        //any input's value falls outside its range, so the outputs always stay aligned. Rows
        //run to the longest input; exhausted inputs contribute NaN, which never triggers a
        //filter since no comparison with NaN is true. Non-finite values are compared like any
        //number, so infinities can be filtered.
        let n = groups.map { $0.1.data.count }.max() ?? 0

        var out = [[Double]](repeating: [], count: groups.count)

        for index in 0..<n {
            var row = [Double](repeating: Double.nan, count: groups.count)
            var filter = false

            for (i, (range, buffer)) in groups.enumerated() {
                if index < buffer.data.count {
                    let value = buffer.data[index]
                    row[i] = value
                    if value < range.min || value > range.max {
                        filter = true
                    }
                }
            }

            if !filter {
                for i in 0..<groups.count {
                    out[i].append(row[i])
                }
            }
        }

        #if DEBUG_ANALYSIS
            debug_noteOutputs(out)
        #endif

        for (i, output) in outputs.enumerated() {
            //Outputs beyond the input count are ignored (matching Android)
            guard i < out.count else { break }
            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(out[i])
            }
        }
    }
}
