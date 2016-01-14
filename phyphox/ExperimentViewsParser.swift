//
//  ExperimentViewsParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentViewsParser: ExperimentMetadataParser {
    var views: [NSDictionary]?
    
    required init(_ data: NSDictionary) {
        views = getElementsWithKey(data, key: "view") as! [NSDictionary]?
    }
    
    enum GraphAxis {
        case x
        case y
    }
    
    func stringToGraphAxis(string: String) -> GraphAxis? {
        if string.lowercaseString == "x" {
            return .x
        }
        else if string.lowercaseString == "y" {
            return .y
        }
        
        return nil
    }
    
    func parse(buffers: [String: DataBuffer]) -> [ExperimentViewCollectionDescriptor]? {
        if views == nil {
            return nil
        }
        
        var viewDescriptors: [ExperimentViewCollectionDescriptor] = []
        
        for view in views! {
            let attributes = view[XMLDictionaryAttributesKey] as! [String: String]
            
            let label = attributes["label"]!
            let labelSize = CGFloatFromXML(attributes, key: "labelsize", defaultValue: 1.0)
            
            var graphDescriptors: [GraphViewDescriptor] = []
            var infoDescriptors: [InfoViewDescriptor] = []
            var editDescriptors: [EditViewDescriptor] = []
            var valueDescriptors: [ValueViewDescriptor] = []
            
            if let graphs = getElementsWithKey(view, key: "graph") as! [NSDictionary]? {
                for graph in graphs {
                    let attributes = graph[XMLDictionaryAttributesKey] as! [String: String]
                    
                    let label = attributes["label"]!
                    let labelSize = CGFloatFromXML(attributes, key: "labelsize", defaultValue: 1.0)
                    let aspectRatio = floatTypeFromXML(attributes, key: "aspectRatio", defaultValue: 3.0)
                    let dots = stringFromXML(attributes, key: "style", defaultValue: "line") == "dots"
                    let partialUpdate = boolFromXML(attributes, key: "partialUpdate", defaultValue: false)
                    let forceFullDataset = boolFromXML(attributes, key: "forceFullDataset", defaultValue: false)
                    let history = intTypeFromXML(attributes, key: "history", defaultValue: UInt(1))
                    
                    let logX = boolFromXML(attributes, key: "logX", defaultValue: false)
                    let logY = boolFromXML(attributes, key: "logY", defaultValue: false)
                    
                    let xLabel = attributes["labelX"]!
                    let yLabel = attributes["labelY"]!
                    
                    var xInputBuffer: DataBuffer?
                    var yInputBuffer: DataBuffer?
                    
                    if let inputs = getElementsWithKey(graph, key: "input") {
                        for input in inputs {
                            if input is NSDictionary {
                                let attributes = input[XMLDictionaryAttributesKey] as! [String: String]
                                
                                let axisString = attributes["axis"]!
                                
                                let axis = stringToGraphAxis(axisString)
                                
                                if axis == nil {
                                    print("Error! Invalid graph axis: \(axisString)")
                                    continue
                                }
                                
                                let bufferName = input[XMLDictionaryTextKey] as! String
                                
                                let buffer = buffers[bufferName]
                                
                                if buffer == nil {
                                    print("Error! Unknown buffer name: \(bufferName)")
                                    continue
                                }
                                else {
                                    switch axis! {
                                    case .y:
                                        yInputBuffer = buffer
                                        break
                                    case .x:
                                        xInputBuffer = buffer
                                        break
                                    }
                                }
                            }
                            else if input is NSString {
                                yInputBuffer = buffers[input as! String]
                            }
                        }
                    }
                    
                    let graphDescriptor = GraphViewDescriptor(label: label, labelSize: labelSize, xLabel: xLabel, yLabel: yLabel, xInputBuffer: xInputBuffer, yInputBuffer: yInputBuffer, logX: logX, logY: logY, aspectRatio: aspectRatio, drawDots: dots, partialUpdate: partialUpdate, forceFullDataset: forceFullDataset, history: history)
                    
                    graphDescriptors.append(graphDescriptor)
                }
            }
            
            if let infos = getElementsWithKey(view, key: "info") as! [NSDictionary]? {
                for info in infos {
                    let attributes = info[XMLDictionaryAttributesKey] as! [String: String]
                    
                    let label = attributes["label"]!
                    let labelSize = CGFloatFromXML(attributes, key: "labelsize", defaultValue: 1.0)
                    
                    let infoDescriptor = InfoViewDescriptor(label: label, labelSize: labelSize)
                    
                    infoDescriptors.append(infoDescriptor)
                }
            }
            
            if let values = getElementsWithKey(view, key: "value") as! [NSDictionary]? {
                for value in values {
                    let attributes = value[XMLDictionaryAttributesKey] as! [String: String]
                    
                    let label = attributes["label"]!
                    let labelSize = CGFloatFromXML(attributes, key: "labelsize", defaultValue: 1.0)
                    
                    let scientific = boolFromXML(attributes, key: "scientific", defaultValue: false)
                    let precision = intTypeFromXML(attributes, key: "precision", defaultValue: 2)
                    
                    let unit = stringFromXML(attributes, key: "unit", defaultValue: "")
                    
                    let factor = floatTypeFromXML(attributes, key: "factor", defaultValue: 1.0)
                    
                    var inputBuffer: DataBuffer? = nil
                    
                    if let input = getElementsWithKey(value, key: "input") {
                        let first = input.first!
                        
                        if first is NSDictionary {
                            let bufferName = (first as! NSDictionary)[XMLDictionaryTextKey] as! String
                            
                            inputBuffer = buffers[bufferName]
                        }
                        else if first is NSString {
                            inputBuffer = buffers[first as! String]
                        }
                    }
                    
                    if inputBuffer == nil {
                        print("Error! No input buffer for value view.")
                        continue
                    }
                    
                    let valueDescriptor = ValueViewDescriptor(label: label, labelSize: labelSize, scientific: scientific, precision: precision, unit: unit, factor: factor)
                    
                    valueDescriptors.append(valueDescriptor)
                }
            }
            
            if let edits = getElementsWithKey(view, key: "edit") as! [NSDictionary]? {
                for edit in edits {
                    let attributes = edit[XMLDictionaryAttributesKey] as! [String: String]
                    
                    let label = attributes["label"]!
                    let labelSize = CGFloatFromXML(attributes, key: "labelsize", defaultValue: 1.0)
                    
                    let signed = boolFromXML(attributes, key: "signed", defaultValue: true)
                    
                    let decimal = boolFromXML(attributes, key: "decimal", defaultValue: true)
                    
                    let unit = stringFromXML(attributes, key: "unit", defaultValue: "")
                    
                    let factor = floatTypeFromXML(attributes, key: "factor", defaultValue: 1.0)
                    
                    let defaultValue = floatTypeFromXML(attributes, key: "default", defaultValue: 0.0)
                    
                    var outputBuffer: DataBuffer? = nil
                    
                    if let input = getElementsWithKey(edit, key: "output") {
                        let first = input.first!
                        
                        if first is NSDictionary {
                            let bufferName = (first as! NSDictionary)[XMLDictionaryTextKey] as! String
                            
                            outputBuffer = buffers[bufferName]
                        }
                        else if first is NSString {
                            outputBuffer = buffers[first as! String]
                        }
                    }
                    
                    if outputBuffer == nil {
                        print("Error! No output buffer for edit view.")
                        continue
                    }
                    
                    let editDescriptor = EditViewDescriptor(label: label, labelSize: labelSize, signed: signed, decimal: decimal, unit: unit, factor: factor, defaultValue: defaultValue)
                    
                    editDescriptors.append(editDescriptor)
                }
            }
            
            let viewDescriptor = ExperimentViewCollectionDescriptor(label: label, labelSize: labelSize, graphViews: (graphDescriptors.count > 0 ? graphDescriptors : nil), infoViews: (infoDescriptors.count > 0 ? infoDescriptors : nil), editViews: (editDescriptors.count > 0 ? editDescriptors : nil), valueViews: (valueDescriptors.count > 0 ? valueDescriptors : nil))
            
            viewDescriptors.append(viewDescriptor)
        }
        
        return (viewDescriptors.count > 0 ? viewDescriptors : nil)
    }
}
