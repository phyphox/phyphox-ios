//
//  ButterworthAnalysis.swift
//  phyphox
//
//  Created by Sebastian Staacks on 06.08.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import Foundation

//Applies the magnitude of a Butterworth filter's transfer function to data in the frequency
//domain (the FFT itself is done separately with the fft module). With only "cutoff" set this is
//a lowpass; with a non-zero "cutoffLow" it becomes a bandpass with -3dB at both cutoffs.
final class ButterworthAnalysis: AutoClearingExperimentAnalysisModule {
    private static let yInSlot = AnalysisIOSlot(name: "y", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let xInSlot = AnalysisIOSlot(name: "x", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let nInSlot = AnalysisIOSlot(name: "n", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let cutoffInSlot = AnalysisIOSlot(name: "cutoff", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let cutoffLowInSlot = AnalysisIOSlot(name: "cutoffLow", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let filteredOutSlot = AnalysisIOSlot(name: "filtered", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [Self.yInSlot, Self.xInSlot, Self.nInSlot, Self.cutoffInSlot, Self.cutoffLowInSlot], outputs: [Self.filteredOutSlot])
    }
    private let yInput: MutableDoubleArray
    private let xInput: MutableDoubleArray
    private let nInput: ExperimentAnalysisDataInput
    private let cutoffInput: ExperimentAnalysisDataInput
    private let cutoffLowInput: ExperimentAnalysisDataInput?

    private let filteredOutput: ExperimentAnalysisDataOutput?

    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        let io = try Self.mapIO(inputs: inputs, outputs: outputs)

        guard let yData = io.data(Self.yInSlot) else {
            throw SerializationError.genericError(message: "Butterworth analysis needs a buffer input designated as \"y\".")
        }
        guard let xData = io.data(Self.xInSlot) else {
            throw SerializationError.genericError(message: "Butterworth analysis needs a buffer input designated as \"x\".")
        }
        guard let tNInput = io.input(Self.nInSlot) else {
            throw SerializationError.genericError(message: "Butterworth analysis needs an input designated as \"n\".")
        }
        guard let tCutoffInput = io.input(Self.cutoffInSlot) else {
            throw SerializationError.genericError(message: "Butterworth analysis needs an input designated as \"cutoff\".")
        }

        yInput = yData
        xInput = xData
        nInput = tNInput
        cutoffInput = tCutoffInput
        cutoffLowInput = io.input(Self.cutoffLowInSlot)

        filteredOutput = io.output(Self.filteredOutSlot)

        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }

    override func update() {
        guard let order = nInput.getSingleValue(), let cutoff = cutoffInput.getSingleValue(), !order.isNaN, !cutoff.isNaN else {
            return
        }
        let cutoffLow = cutoffLowInput?.getSingleValue() ?? 0.0

        let y = yInput.data
        let x = xInput.data
        let count = Swift.min(y.count, x.count)

        var filtered = [Double]()
        filtered.reserveCapacity(count)

        for i in 0..<count {
            let f = abs(x[i])
            let gain: Double
            if cutoffLow > 0.0 {
                //Bandpass from the standard lowpass-to-bandpass transformation:
                //|H|^2 = 1 / (1 + ((f^2 - fl*fh) / (f*(fh - fl)))^2n), unity at sqrt(fl*fh), -3dB at fl and fh
                if f == 0.0 {
                    gain = 0.0
                } else {
                    let ratio = (f * f - cutoffLow * cutoff) / (f * (cutoff - cutoffLow))
                    gain = 1.0 / sqrt(1.0 + pow(ratio * ratio, order))
                }
            } else {
                //Lowpass: |H|^2 = 1 / (1 + (f/fh)^2n)
                let ratio = f / cutoff
                gain = 1.0 / sqrt(1.0 + pow(ratio * ratio, order))
            }
            filtered.append(y[i] * gain)
        }

        if let filteredOutput = filteredOutput {
            switch filteredOutput {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(filtered)
            }
        }
    }
}
