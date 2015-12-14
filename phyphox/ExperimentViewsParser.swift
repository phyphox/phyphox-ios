//
//  ExperimentViewsParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import UIKit

final class ExperimentViewsParser: ExperimentMetadataParser {
    var views: [NSDictionary]?
    
    required init(_ data: NSDictionary) {
        views = getElementsWithKey(data, key: "view") as! [NSDictionary]?
    }
    
    func parse() -> AnyObject {
        fatalError("Unavailable");
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
    
    func parse(buffers: [String: DataBuffer]) -> [ExperimentViewDescriptor]? {
        if views == nil {
            return nil
        }
        
        var viewDescriptors: [ExperimentViewDescriptor] = []
        
        for view in views! {
            let attributes = view[XMLDictionaryAttributesKey] as! [String: String]
            
            let label = attributes["label"]!
            let labelSize = doubleFromXML(attributes, key: "labelsize", defaultValue: 1.0)
            
            var graphDescriptors: [GraphViewDescriptor] = []
            var editDescriptors: [EditViewDescriptor] = []
            var valueDescriptors: [ValueViewDescriptor] = []
            
            if let graphs = getElementsWithKey(view, key: "graph") as! [NSDictionary]? {
                for graph in graphs {
                    let attributes = graph[XMLDictionaryAttributesKey] as! [String: String]
                    
                    let label = attributes["label"]!
                    let labelSize = doubleFromXML(attributes, key: "labelsize", defaultValue: 1.0)
                    let aspectRatio = doubleFromXML(attributes, key: "aspectRatio", defaultValue: 3.0)
                    let dots = stringFromXML(attributes, key: "style", defaultValue: "line") == "dots"
                    let partialUpdate = boolFromXML(attributes, key: "partialUpdate", defaultValue: false)
                    let forceFullDataset = boolFromXML(attributes, key: "forceFullDataset", defaultValue: false)
                    let history = uintFromXML(attributes, key: "history", defaultValue: 1)
                    
                    let logX = boolFromXML(attributes, key: "logX", defaultValue: false)
                    let logY = boolFromXML(attributes, key: "logY", defaultValue: false)
                    
                    let xLabel = attributes["labelX"]!
                    let yLabel = attributes["labelY"]!
                    
                    var xInputBuffer: DataBuffer?
                    var yInputBuffer: DataBuffer?
                    
                    if let inputs = getElementsWithKey(graph, key: "input") as! [NSDictionary]? {
                        for input in inputs {
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
                    }
                    
                    let graphDescriptor = GraphViewDescriptor(label: label, labelSize: labelSize, xLabel: xLabel, yLabel: yLabel, xInputBuffer: xInputBuffer, yInputBuffer: yInputBuffer, logX: logX, logY: logY, aspectRatio: aspectRatio, drawDots: dots, partialUpdate: partialUpdate, forceFullDataset: forceFullDataset, history: history)
                    
                    graphDescriptors.append(graphDescriptor)
                }
            }
            
            if let values = getElementsWithKey(view, key: "value") as! [NSDictionary]? {
                for value in values {
                    let attributes = value[XMLDictionaryAttributesKey] as! [String: String]
                    
                    let label = attributes["label"]!
                    let labelSize = doubleFromXML(attributes, key: "labelsize", defaultValue: 1.0)
                    
                    let scientific = boolFromXML(attributes, key: "scientific", defaultValue: false)
                    let precision = intFromXML(attributes, key: "precision", defaultValue: 2)
                    
                    let unit = stringFromXML(attributes, key: "unit", defaultValue: "")
                    
                    let factor = doubleFromXML(attributes, key: "factor", defaultValue: 1.0)
                    
                    var inputBuffer: DataBuffer? = nil
                    
                    if let input = (getElementsWithKey(value, key: "input") as! [NSDictionary]?)?.first {
                        let bufferName = input[XMLDictionaryTextKey] as! String
                        
                        inputBuffer = buffers[bufferName]
                    }
                    
                    if inputBuffer == nil {
                        print("Error! No input buffer for value view.")
                        continue
                    }
                    
                    let valueDescriptor = ValueViewDescriptor(label: label, labelSize: labelSize)
                    
                    valueDescriptors.append(valueDescriptor)
                    //TODO: Value view descriptor
                }
            }
            
            if let edits = getElementsWithKey(view, key: "edit") as! [NSDictionary]? {
                for edit in edits {
                    let attributes = edit[XMLDictionaryAttributesKey] as! [String: String]
                    
                    let label = attributes["label"]!
                    let labelSize = doubleFromXML(attributes, key: "labelsize", defaultValue: 1.0)
                    
                    let signed = boolFromXML(attributes, key: "signed", defaultValue: true)
                    
                    let decimal = boolFromXML(attributes, key: "decimal", defaultValue: true)
                    
                    let unit = stringFromXML(attributes, key: "unit", defaultValue: "")
                    
                    let factor = doubleFromXML(attributes, key: "factor", defaultValue: 1.0)
                    
                    let defaultValue = doubleFromXML(attributes, key: "default", defaultValue: 0.0)
                    
                    var outputBuffer: DataBuffer? = nil
                    
                    if let input = (getElementsWithKey(edit, key: "output") as! [NSDictionary]?)?.first {
                        let bufferName = input[XMLDictionaryTextKey] as! String
                        
                        outputBuffer = buffers[bufferName]
                    }
                    
                    if outputBuffer == nil {
                        print("Error! No output buffer for edit view.")
                        continue
                    }
                    
                    let editDescriptor = EditViewDescriptor(label: label, labelSize: labelSize)
                    
                    editDescriptors.append(editDescriptor)
                    //TODO: Edit view descriptor
                }
            }
            
            let viewDescriptor = ExperimentViewDescriptor(label: label, labelSize: labelSize, graphViews: (graphDescriptors.count > 0 ? graphDescriptors : nil), editViews: (editDescriptors.count > 0 ? editDescriptors : nil), valueViews: (valueDescriptors.count > 0 ? valueDescriptors : nil))
            
            viewDescriptors.append(viewDescriptor)
        }
        
        return (viewDescriptors.count > 0 ? viewDescriptors : nil)
    }
}
