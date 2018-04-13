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
                throw ParseError.missingElement("data-container")
            }

            self = .buffer(buffer: buffer, usedAs: usedAs, clear: clear)
        case .value(value: let value, usedAs: let usedAs):
            self = .value(value: value, usedAs: usedAs)
        case .empty(let asString):
            self = .buffer(buffer: emptyBuffer, usedAs: asString, clear: false)
        }
    }
}

struct ExperimentAnalysisFactory {
    static func analysisModule(from descriptor: AnalysisModuleDescriptor, for key: String, buffers: [String: DataBuffer]) throws -> ExperimentAnalysisModule {
        let inputs = try descriptor.inputs.map { try ExperimentAnalysisDataIO(descriptor: $0, buffers: buffers) }
        let outputs = try descriptor.outputs.map { try ExperimentAnalysisDataIO(descriptor: $0, buffers: buffers) }
        let attributes = descriptor.attributes

        let analysisClass: ExperimentAnalysisModule.Type

        if key == "add" {
            analysisClass = AdditionAnalysis.self
        }
        else if key == "subtract" {
            analysisClass = SubtractionAnalysis.self
        }
        else if key == "multiply" {
            analysisClass = MultiplicationAnalysis.self
        }
        else if key == "divide" {
            analysisClass = DivisionAnalysis.self
        }
        else if key == "power" {
            analysisClass = PowerAnalysis.self
        }
        else if key == "gcd" {
            analysisClass = GCDAnalysis.self
        }
        else if key == "lcm" {
            analysisClass = LCMAnalysis.self
        }
        else if key == "abs" {
            analysisClass = ABSAnalysis.self
        }
        else if key == "round" {
            analysisClass = RoundAnalysis.self
        }
        else if key == "log" {
            analysisClass = LogAnalysis.self
        }
        else if key == "sin" {
            analysisClass = SinAnalysis.self
        }
        else if key == "cos" {
            analysisClass = CosAnalysis.self
        }
        else if key == "tan" {
            analysisClass = TanAnalysis.self
        }
        else if key == "sinh" {
            analysisClass = SinAnalysis.self
        }
        else if key == "cosh" {
            analysisClass = CosAnalysis.self
        }
        else if key == "tanh" {
            analysisClass = TanAnalysis.self
        }
        else if key == "asin" {
            analysisClass = AsinAnalysis.self
        }
        else if key == "acos" {
            analysisClass = AcosAnalysis.self
        }
        else if key == "atan" {
            analysisClass = AtanAnalysis.self
        }
        else if key == "atan2" {
            analysisClass = Atan2Analysis.self
        }
        else if key == "first" {
            analysisClass = FirstAnalysis.self
        }
        else if key == "max" {
            analysisClass = MaxAnalysis.self
        }
        else if key == "min" {
            analysisClass = MinAnalysis.self
        }
        else if key == "threshold" {
            analysisClass = ThresholdAnalysis.self
        }
        else if key == "append" {
            analysisClass = AppendAnalysis.self
        }
        else if key == "fft" {
            analysisClass = FFTAnalysis.self
        }
        else if key == "autocorrelation" {
            analysisClass = AutocorrelationAnalysis.self
        }
        else if key == "differentiate" {
            analysisClass = DifferentiationAnalysis.self
        }
        else if key == "integrate" {
            analysisClass = IntegrationAnalysis.self
        }
        else if key == "crosscorrelation" {
            analysisClass = CrosscorrelationAnalysis.self
        }
        else if key == "gausssmooth" {
            analysisClass = GaussSmoothAnalysis.self
        }
        else if key == "match" {
            analysisClass = MatchAnalysis.self
        }
        else if key == "rangefilter" {
            analysisClass = RangefilterAnalysis.self
        }
        else if key == "subrange" {
            analysisClass = SubrangeAnalysis.self
        }
        else if key == "ramp" {
            analysisClass = RampGeneratorAnalysis.self
        }
        else if key == "const" {
            analysisClass = ConstGeneratorAnalysis.self
        }
        else if key == "periodicity" {
            analysisClass = PeriodicityAnalysis.self
        }
        else if key == "timer" {
            analysisClass = TimerAnalysis.self
        }
        else if key == "count" {
            analysisClass = CountAnalysis.self
        }
        else if key == "average" {
            analysisClass = AverageAnalysis.self
        }
        else if key == "binning" {
            analysisClass = BinningAnalysis.self
        }
        else if key == "if" {
            analysisClass = IfAnalysis.self
        }
        else {
            throw SerializationError.invalidExperimentFile(message: "Error! Invalid analysis type: \(key)")
        }

        return try analysisClass.init(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
    }
}
