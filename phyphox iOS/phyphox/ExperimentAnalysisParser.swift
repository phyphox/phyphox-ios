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
    
    func parse(buffers: [String : DataBuffer]) -> ExperimentAnalysis? {
        if analyses == nil {
            return nil
        }
        
        let sleep = floatTypeFromXML(attributes, key: "sleep", defaultValue: 0.0)
        let onUserInput = boolFromXML(attributes, key: "onUserInout", defaultValue: false)
        
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
                    analysis = AdditionAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "subtract" {
                    analysis = SubtractionAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "multiply" {
                     analysis = MultiplicationAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "divide" {
                    analysis = DivisionAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "power" {
                    analysis = PowerAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "gcd" {
                    analysis = GCDAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "lcm" {
                    analysis = LCMAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "abs" {
                    analysis = ABSAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "sin" {
                    analysis = SinAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "cos" {
                    analysis = CosAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "tan" {
                    analysis = TanAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "first" {
                    analysis = FirstAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "max" {
                    analysis = MaxAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "min" {
                    analysis = MinAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "threshold" {
                    analysis = ThresholdAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "append" {
                    analysis = AppendAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "fft" {
                    analysis = FFTAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "autocorrelation" {
                    analysis = AutocorrelationAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "differentiate" {
                    analysis = DifferentiationAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "integrate" {
                    analysis = IntegrationAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "crosscorrelation" {
                    analysis = CrosscorrelationAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "gausssmooth" {
                    analysis = GaussSmoothAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "match" {
                    analysis = MatchAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "rangefilter" {
                    analysis = RangefilterAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "ramp" {
                    analysis = RampGeneratorAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "const" {
                    analysis = ConstGeneratorAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "periodicity" {
                    analysis = PeriodicityAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "timer" {
                    analysis = TimerAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else {
                    print("Error! Invalid analysis type: \(key)")
                }
                
                if analysis != nil {
                    if index >= processed.count {
                        processed.appendContentsOf([ExperimentAnalysisModule!](count: index-processed.count+1, repeatedValue: nil))
                    }
                    
                    processed[index] = analysis
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
