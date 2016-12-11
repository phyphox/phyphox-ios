//
//  ExperimentAnalysisParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
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
                a[key] = (getElemetArrayFromValue(value) as! [NSDictionary])
            }
            
        }
        
        if a.count > 0 {
            analyses = a
        }
        else {
            analyses = nil
        }
    }
    
    func parse(buffers: [String : DataBuffer]) throws -> ExperimentAnalysis? {
        if analyses == nil {
            return nil
        }
        
        let sleep = floatTypeFromXML(attributes, key: "sleep", defaultValue: 0.0)
        let onUserInput = boolFromXML(attributes, key: "onUserInput", defaultValue: false)
        
        func getDataFlows(dictionaries: [AnyObject]?) -> [ExperimentAnalysisDataIO] {
            var a = [ExperimentAnalysisDataIO]()
            
            if dictionaries != nil {
                for object in dictionaries! {
                    if object is NSDictionary {
                        a.append(ExperimentAnalysisDataIO(dictionary: object as! NSDictionary, buffers: buffers))
                    }
                    else {
                        a.append(ExperimentAnalysisDataIO(buffer: buffers[object as! String]!))
                    }
                }
            }
            
            return a
        }
        
        var processed: [ExperimentAnalysisModule!] = []
        
        for (key, values) in analyses! {
            if key == "__count" || key == "__index" {
                continue
            }
            
            for value in values as! [NSDictionary] {
                let inputs = getDataFlows(getElementsWithKey(value, key: "input"))
                let outputs = getDataFlows(getElementsWithKey(value, key: "output"))
                
                let attributes = value[XMLDictionaryAttributesKey] as! [String: AnyObject]?
                
                var analysis: ExperimentAnalysisModule! = nil
                
                let index = (value["__index"] as! NSNumber).integerValue
                
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
                    throw SerializationError.InvalidExperimentFile(message: "Error! Invalid analysis type: \(key)")
                }
                
                if analysis != nil {
                    if index >= processed.count {
                        processed.appendContentsOf([ExperimentAnalysisModule!](count: index-processed.count+1, repeatedValue: nil))
                    }
                    
                    processed[index] = analysis
                    
                    for output in outputs {
                        output.buffer?.dataFromAnalysis = true
                    }
                }
            }
        }
        
        var deleteIndices: [Int] = []
        
        for (i, v) in processed.enumerate() {
            if v == nil {
                deleteIndices.append(i)
            }
        }
        
        if deleteIndices.count > 0 {
            processed.removeAtIndices(deleteIndices)
        }
        
        if processed.count > 0 {
            return ExperimentAnalysis(analyses: processed as! [ExperimentAnalysisModule], sleep: sleep, onUserInput: onUserInput)
        }
        
        return nil
    }
}
