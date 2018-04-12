//
//  ExperimentAnalysisFactory.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

private extension ExperimentAnalysisDataIO {
    init(descriptor: ExperimentAnalysisDataIODescriptor, buffers: [String: DataBuffer]) throws {
        switch descriptor {
        case .buffer(name: let bufferName, usedAs: let usedAs, clear: let clear):
            guard let buffer = buffers[bufferName] else {
                throw ParseError.missingElement
            }

            self = .buffer(buffer: buffer, usedAs: usedAs, clear: clear)
        case .value(value: let value, usedAs: let usedAs):
            self = .value(value: value, usedAs: usedAs)
        }
    }
}

struct ExperimentAnalysisFactory {
    static func analysisModule(from descriptor: AnalysisModuleDescriptor, for key: String, buffers: [String: DataBuffer]) throws -> ExperimentAnalysisModule {
        let inputs = try descriptor.inputs.map { try ExperimentAnalysisDataIO(descriptor: $0, buffers: buffers) }
        let outputs = try descriptor.outputs.map { try ExperimentAnalysisDataIO(descriptor: $0, buffers: buffers) }
        let attributes = descriptor.attributes

        let analysis: ExperimentAnalysisModule

        if key == "add" {
            analysis = try AdditionAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "subtract" {
            analysis = try SubtractionAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "multiply" {
            analysis = try MultiplicationAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "divide" {
            analysis = try DivisionAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "power" {
            analysis = try PowerAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "gcd" {
            analysis = try GCDAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "lcm" {
            analysis = try LCMAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "abs" {
            analysis = try ABSAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "round" {
            analysis = try RoundAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "log" {
            analysis = try LogAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "sin" {
            analysis = try SinAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "cos" {
            analysis = try CosAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "tan" {
            analysis = try TanAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "sinh" {
            analysis = try SinAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "cosh" {
            analysis = try CosAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "tanh" {
            analysis = try TanAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "asin" {
            analysis = try AsinAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "acos" {
            analysis = try AcosAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "atan" {
            analysis = try AtanAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "atan2" {
            analysis = try Atan2Analysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "first" {
            analysis = try FirstAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "max" {
            analysis = try MaxAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "min" {
            analysis = try MinAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "threshold" {
            analysis = try ThresholdAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "append" {
            analysis = try AppendAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "fft" {
            analysis = try FFTAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "autocorrelation" {
            analysis = try AutocorrelationAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "differentiate" {
            analysis = try DifferentiationAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "integrate" {
            analysis = try IntegrationAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "crosscorrelation" {
            analysis = try CrosscorrelationAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "gausssmooth" {
            analysis = try GaussSmoothAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "match" {
            analysis = try MatchAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "rangefilter" {
            analysis = try RangefilterAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "subrange" {
            analysis = try SubrangeAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "ramp" {
            analysis = try RampGeneratorAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "const" {
            analysis = try ConstGeneratorAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "periodicity" {
            analysis = try PeriodicityAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "timer" {
            analysis = try TimerAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "count" {
            analysis = try CountAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "average" {
            analysis = try AverageAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "binning" {
            analysis = try BinningAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else if key == "if" {
            analysis = try IfAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
        }
        else {
            throw SerializationError.invalidExperimentFile(message: "Error! Invalid analysis type: \(key)")
        }

        return analysis
    }
}
