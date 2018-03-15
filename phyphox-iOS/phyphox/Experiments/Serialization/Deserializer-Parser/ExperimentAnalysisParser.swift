//
//  ExperimentAnalysisParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

final class ExperimentAnalysisParser: ExperimentMetadataParser {
    let analyses: [String: AnyObject]?
    var attributes: [String: String]?
    
    required init(_ data: NSDictionary) {
        var a: [String: AnyObject] = [:]
        
        for (key, value) in data as! [String: AnyObject] {
            if key == XMLDictionaryAttributesKey {
                attributes = (value as! [String: String])
            }
            else {
                a[key] = (getElemetArrayFromValue(value) as! [NSDictionary] as AnyObject)
            }
            
        }
        
        if a.count > 0 {
            analyses = a
        }
        else {
            analyses = nil
        }
    }

    func getInputBufferNames() -> Set<String> {
        var names = Set<String>()

        guard let analyses = analyses else { return names }

        for (key, values) in analyses {
            guard let values = values as? [NSDictionary], key != "__count" && key != "__index" else {
                continue
            }

            for value in values {
                guard let inputs = getElementsWithKey(value, key: "input") else { continue }

                for input in inputs {
                    if let input = input as? NSDictionary {
                        if let bufferName = input[XMLDictionaryTextKey] as? String {
                            names.insert(bufferName)
                        }
                    }
                    else if let input = input as? String {
                        names.insert(input)
                    }
                }
            }
        }

        return names
    }
    
    func parse(_ buffers: [String : DataBuffer]) throws -> ExperimentAnalysis? {
        guard let analyses = analyses else { return nil }
        
        let sleep = floatTypeFromXML(attributes as [String : AnyObject]?, key: "sleep", defaultValue: 0.0)
        let dsBufferName = attributes?["dynamicSleep"]
        let dynamicSleep: DataBuffer?
        if dsBufferName != nil {
            dynamicSleep = buffers[dsBufferName!]!
        } else {
            dynamicSleep = nil
        }

        func getDataFlows(_ dictionaries: [AnyObject]?) throws -> [ExperimentAnalysisDataIO] {
            guard let dictionaries = dictionaries else { return [] }

            var a = [ExperimentAnalysisDataIO]()

            for object in dictionaries {
                if let object = object as? NSDictionary {
                    a.append(try ExperimentAnalysisDataIO(dictionary: object, buffers: buffers))
                }
                else if let object = object as? String {
                    a.append(ExperimentAnalysisDataIO(buffer: buffers[object]!))
                }
            }
            
            return a
        }
        
        var processed: [ExperimentAnalysisModule?] = []
        
        for (key, values) in analyses {
            if key == "__count" || key == "__index" {
                continue
            }
            
            for value in values as! [NSDictionary] {
                let inputs = try getDataFlows(getElementsWithKey(value, key: "input"))
                let outputs = try getDataFlows(getElementsWithKey(value, key: "output"))
                
                let attributes = value[XMLDictionaryAttributesKey] as! [String: AnyObject]?
                
                var analysis: ExperimentAnalysisModule! = nil
                
                let index = (value["__index"] as! NSNumber).intValue
                
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
                
                if analysis != nil {
                    if index >= processed.count {
                        for _ in processed.count...index {
                            processed.append(nil)
                        }
                    }
                    
                    processed[index] = analysis
                }
            }
        }

        if processed.count > 0 {
            return ExperimentAnalysis(modules: processed.flatMap { $0 }, sleep: sleep, dynamicSleep: dynamicSleep)
        }
        
        return nil
    }
}
