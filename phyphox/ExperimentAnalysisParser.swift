//
//  ExperimentAnalysisParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentAnalysisParser: ExperimentMetadataParser {
    let analyses: [String: [NSDictionary]]?
    var attributes: [String: String]?
    
    required init(_ data: NSDictionary) {
        var a: [String: [NSDictionary]] = [:]
        
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
        
        func getDataFlows(dictionaries: [AnyObject]) -> [ExperimentAnalysisDataIO] {
            let c = dictionaries.count
            var a = [ExperimentAnalysisDataIO!](count: c, repeatedValue: nil)
            
            for (i, object) in dictionaries.enumerate() {
                if object is NSDictionary {
                    a[i] = ExperimentAnalysisDataIO(dictionary: object as! NSDictionary, buffers: buffers)
                }
                else {
                    a[i] = ExperimentAnalysisDataIO(buffer: buffers[object as! String]!)
                }
            }
            
            return a as! [ExperimentAnalysisDataIO]
        }
        
        var processed: [ExperimentAnalysisModule] = []
        
        for (key, values) in analyses! {
            for value in values {
                let inputs = getDataFlows(getElementsWithKey(value, key: "input")!)
                let outputs = getDataFlows(getElementsWithKey(value, key: "output")!)
                
                let attributes = value[XMLDictionaryAttributesKey] as! [String: AnyObject]?
                
                var analysis: ExperimentAnalysisModule! = nil
                
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
                else if key == "rangefilter" {
                    analysis = RangefilterAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "ramp" {
                    analysis = RampGeneratorAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else if key == "const" {
                    analysis = ConstGeneratorAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: attributes)
                }
                else {
                    print("Error! Invalid analysis type: \(key)")
                }
                
                if analysis != nil {
                    processed.append(analysis)
                }
            }
        }
        
        if processed.count > 0 {
            return ExperimentAnalysis(analyses: processed, sleep: sleep, onUserInput: onUserInput)
        }
        
        return nil
    }
}
