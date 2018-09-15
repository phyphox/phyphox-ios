//
//  ExperimentAnalysisFactory.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

// Helpers for `AnalysisElementHandler`.

private extension ExperimentAnalysisDataIO {
    init(descriptor: ExperimentAnalysisDataIODescriptor, buffers: [String: DataBuffer]) throws {
        switch descriptor {
        case .buffer(name: let bufferName, usedAs: let usedAs, clear: let clear):
            guard let buffer = buffers[bufferName] else {
                throw ElementHandlerError.missingElement("data-container")
            }

            self = .buffer(buffer: buffer, usedAs: usedAs, clear: clear)
        case .value(value: let value, usedAs: let usedAs):
            self = .value(value: value, usedAs: usedAs)
        case .empty(let asString):
            self = .buffer(buffer: emptyBuffer, usedAs: asString, clear: false)
        }
    }
}

final class ExperimentAnalysisFactory {
    private static let classMap = [
        "add": AdditionAnalysis.self,
        "subtract": SubtractionAnalysis.self,
        "multiply": MultiplicationAnalysis.self,
        "divide": DivisionAnalysis.self,
        "power": PowerAnalysis.self,
        "gcd": GCDAnalysis.self,
        "lcm": LCMAnalysis.self,
        "abs": ABSAnalysis.self,
        "round": RoundAnalysis.self,
        "log": LogAnalysis.self,
        "sin": SinAnalysis.self,
        "cos": CosAnalysis.self,
        "tan": TanAnalysis.self,
        "sinh": SinAnalysis.self,
        "cosh": CosAnalysis.self,
        "tanh": TanAnalysis.self,
        "asin": AsinAnalysis.self,
        "acos": AcosAnalysis.self,
        "atan": AtanAnalysis.self,
        "atan2": Atan2Analysis.self,
        "first": FirstAnalysis.self,
        "max": MaxAnalysis.self,
        "min": MinAnalysis.self,
        "threshold": ThresholdAnalysis.self,
        "append": AppendAnalysis.self,
        "fft": FFTAnalysis.self,
        "autocorrelation": AutocorrelationAnalysis.self,
        "differentiate": DifferentiationAnalysis.self,
        "integrate": IntegrationAnalysis.self,
        "crosscorrelation": CrosscorrelationAnalysis.self,
        "gausssmooth": GaussSmoothAnalysis.self,
        "match": MatchAnalysis.self,
        "rangefilter": RangefilterAnalysis.self,
        "subrange": SubrangeAnalysis.self,
        "ramp": RampGeneratorAnalysis.self,
        "const": ConstGeneratorAnalysis.self,
        "periodicity": PeriodicityAnalysis.self,
        "timer": TimerAnalysis.self,
        "count": CountAnalysis.self,
        "average": AverageAnalysis.self,
        "binning": BinningAnalysis.self,
        "if": IfAnalysis.self]

    static func analysisModule(from descriptor: AnalysisModuleDescriptor, for key: String, buffers: [String: DataBuffer]) throws -> ExperimentAnalysisModule {
        guard let analysisClass = classMap[key] else {
            throw ElementHandlerError.unexpectedChildElement(key)
        }

        let inputs = try descriptor.inputs.map { try ExperimentAnalysisDataIO(descriptor: $0, buffers: buffers) }
        let outputs = try descriptor.outputs.map { try ExperimentAnalysisDataIO(descriptor: $0, buffers: buffers) }
        let attributes = descriptor.attributes

        return try analysisClass.init(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
    }
}
