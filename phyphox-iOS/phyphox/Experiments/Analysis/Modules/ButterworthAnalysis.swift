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
    private let yInput: MutableDoubleArray
    private let xInput: MutableDoubleArray
    private let nInput: ExperimentAnalysisDataInput
    private let cutoffInput: ExperimentAnalysisDataInput
    private let cutoffLowInput: ExperimentAnalysisDataInput?

    private let filteredOutput: ExperimentAnalysisDataOutput?

    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        var tY: ExperimentAnalysisDataInput?
        var tX: ExperimentAnalysisDataInput?
        var tN: ExperimentAnalysisDataInput?
        var tCutoff: ExperimentAnalysisDataInput?
        var tCutoffLow: ExperimentAnalysisDataInput?

        for input in inputs {
            switch input.asString.lowercased() { //Slot names are matched case-insensitively
            case "y": tY = input
            case "x": tX = input
            case "n": tN = input
            case "cutoff": tCutoff = input
            case "cutofflow": tCutoffLow = input
            default: throw SerializationError.genericError(message: "Error: Invalid analysis input for butterworth module: \(String(describing: input.asString))")
            }
        }

        guard case .buffer(buffer: _, data: let yData, usedAs: _, keep: _)? = tY else {
            throw SerializationError.genericError(message: "Butterworth analysis needs a buffer input designated as \"y\".")
        }
        guard case .buffer(buffer: _, data: let xData, usedAs: _, keep: _)? = tX else {
            throw SerializationError.genericError(message: "Butterworth analysis needs a buffer input designated as \"x\".")
        }
        guard let tNInput = tN else {
            throw SerializationError.genericError(message: "Butterworth analysis needs an input designated as \"n\".")
        }
        guard let tCutoffInput = tCutoff else {
            throw SerializationError.genericError(message: "Butterworth analysis needs an input designated as \"cutoff\".")
        }

        yInput = yData
        xInput = xData
        nInput = tNInput
        cutoffInput = tCutoffInput
        cutoffLowInput = tCutoffLow

        filteredOutput = outputs.first

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
