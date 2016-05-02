//
//  ExperimentViewsParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
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
    
    func parse(buffers: [String: DataBuffer], analysis: ExperimentAnalysis?, translation: ExperimentTranslationCollection?) -> [ExperimentViewCollectionDescriptor]? {
        if views == nil {
            return nil
        }
        
        var viewDescriptors: [ExperimentViewCollectionDescriptor] = []
        
        for view in views! {
            let attributes = view[XMLDictionaryAttributesKey] as! [String: String]
            
            let label = attributes["label"]!
            
            var views = [ViewDescriptor!](count: (view["__count"] as! NSNumber).integerValue, repeatedValue: nil)
            
            func handleEdit(edit: [String: AnyObject]) -> EditViewDescriptor? {
                let attributes = edit[XMLDictionaryAttributesKey] as! [String: String]
                
                let label = attributes["label"]!
                
                let signed = boolFromXML(attributes, key: "signed", defaultValue: true)
                
                let decimal = boolFromXML(attributes, key: "decimal", defaultValue: true)
                
                let unit = attributes["unit"]
                
                let factor = floatTypeFromXML(attributes, key: "factor", defaultValue: 1.0)
                
                let defaultValue = floatTypeFromXML(attributes, key: "default", defaultValue: 0.0)
                
                var outputBuffer: DataBuffer? = nil
                
                if let output = getElementsWithKey(edit, key: "output") {
                    let first = output.first!
                    
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
                    return nil
                }
                
                //Register for updates
                if analysis != nil {
                    analysis!.registerEditBuffer(outputBuffer!)
                }
                
                outputBuffer!.attachedToTextField = true
                
                if outputBuffer!.last == nil {
                    outputBuffer!.append(defaultValue) //Set the default value.
                }
                
                return EditViewDescriptor(label: label, translation: translation, signed: signed, decimal: decimal, unit: unit, factor: factor, defaultValue: defaultValue, buffer: outputBuffer!)
            }
            
            func handleValue(value: [String: AnyObject]) -> ValueViewDescriptor? {
                let attributes = value[XMLDictionaryAttributesKey] as! [String: String]
                
                let label = attributes["label"]!
                
                let scientific = boolFromXML(attributes, key: "scientific", defaultValue: false)
                let precision = intTypeFromXML(attributes, key: "precision", defaultValue: 2)
                
                let unit = attributes["unit"]
                
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
                    return nil
                }
                
                return ValueViewDescriptor(label: label, translation: translation, scientific: scientific, precision: precision, unit: unit, factor: factor, buffer: inputBuffer!)
            }
            
            func handleGraph(graph: [String: AnyObject]) -> GraphViewDescriptor? {
                let attributes = graph[XMLDictionaryAttributesKey] as! [String: String]
                
                let label = attributes["label"]!
                
                let aspectRatio = CGFloatFromXML(attributes, key: "aspectRatio", defaultValue: 3.0)
                let dots = stringFromXML(attributes, key: "style", defaultValue: "line") == "dots"
                let partialUpdate = boolFromXML(attributes, key: "partialUpdate", defaultValue: false)
                let forceFullDataset = boolFromXML(attributes, key: "forceFullDataset", defaultValue: false)
                let history = intTypeFromXML(attributes, key: "history", defaultValue: UInt(1))
                
                let logX = boolFromXML(attributes, key: "logX", defaultValue: false)
                let logY = boolFromXML(attributes, key: "logY", defaultValue: false)
                
                let scaleMinX: GraphViewDescriptor.scaleMode
                switch stringFromXML(attributes, key: "scaleMinX", defaultValue: "auto") {
                    case "auto": scaleMinX = GraphViewDescriptor.scaleMode.auto
                    case "extend": scaleMinX = GraphViewDescriptor.scaleMode.extend
                    case "fixed": scaleMinX = GraphViewDescriptor.scaleMode.fixed
                    default:
                        scaleMinX = GraphViewDescriptor.scaleMode.auto
                        print("Error! Unknown value for scaleMinX.")
                }
                let scaleMaxX: GraphViewDescriptor.scaleMode
                switch stringFromXML(attributes, key: "scaleMaxX", defaultValue: "auto") {
                    case "auto": scaleMaxX = GraphViewDescriptor.scaleMode.auto
                    case "extend": scaleMaxX = GraphViewDescriptor.scaleMode.extend
                    case "fixed": scaleMaxX = GraphViewDescriptor.scaleMode.fixed
                    default:
                        scaleMaxX = GraphViewDescriptor.scaleMode.auto
                        print("Error! Unknown value for scaleMaxX.")
                }
                let scaleMinY: GraphViewDescriptor.scaleMode
                switch stringFromXML(attributes, key: "scaleMinY", defaultValue: "auto") {
                    case "auto": scaleMinY = GraphViewDescriptor.scaleMode.auto
                    case "extend": scaleMinY = GraphViewDescriptor.scaleMode.extend
                    case "fixed": scaleMinY = GraphViewDescriptor.scaleMode.fixed
                    default:
                        scaleMinY = GraphViewDescriptor.scaleMode.auto
                        print("Error! Unknown value for scaleMinY.")
                }
                let scaleMaxY: GraphViewDescriptor.scaleMode
                switch stringFromXML(attributes, key: "scaleMaxY", defaultValue: "auto") {
                    case "auto": scaleMaxY = GraphViewDescriptor.scaleMode.auto
                    case "extend": scaleMaxY = GraphViewDescriptor.scaleMode.extend
                    case "fixed": scaleMaxY = GraphViewDescriptor.scaleMode.fixed
                    default:
                        scaleMaxY = GraphViewDescriptor.scaleMode.auto
                        print("Error! Unknown value for scaleMaxY.")
                }
                
                let minX = CGFloatFromXML(attributes, key: "minX", defaultValue: 0.0)
                let maxX = CGFloatFromXML(attributes, key: "maxX", defaultValue: 0.0)
                let minY = CGFloatFromXML(attributes, key: "minY", defaultValue: 0.0)
                let maxY = CGFloatFromXML(attributes, key: "maxY", defaultValue: 0.0)
                
                
                let xLabel = attributes["labelX"]!
                let yLabel = attributes["labelY"]!
                
                var xInputBuffer: DataBuffer?
                var yInputBuffer: DataBuffer?
                
                if let inputs = getElementsWithKey(graph, key: "input") {
                    for input_ in inputs {
                        if let input = input_ as? [String: AnyObject] {
                            let attributes = input[XMLDictionaryAttributesKey] as! [String: AnyObject]
                            
                            let axisString = attributes["axis"] as! String
                            
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
                        else if input_ is NSString {
                            yInputBuffer = buffers[input_ as! String]
                        }
                    }
                }
                
                if yInputBuffer == nil {
                    print("Error! No Y axis input buffer!")
                }
                
                return GraphViewDescriptor(label: label, translation: translation, xLabel: xLabel, yLabel: yLabel, xInputBuffer: xInputBuffer, yInputBuffer: yInputBuffer!, logX: logX, logY: logY, scaleMinX: scaleMinX, scaleMaxX: scaleMaxX, scaleMinY: scaleMinY, scaleMaxY: scaleMaxY, minX: minX, maxX: maxX, minY: minY, maxY: maxY, aspectRatio: aspectRatio, drawDots: dots, partialUpdate: partialUpdate, forceFullDataset: forceFullDataset, history: history)
            }
            
            func handleInfo(info: [String: AnyObject]) -> InfoViewDescriptor? {
                let attributes = info[XMLDictionaryAttributesKey] as! [String: String]
                
                let label = attributes["label"]!
                
                return InfoViewDescriptor(label: label, translation: translation)
            }
            
            var deleteIndices: [Int] = []
            
            for (key, child) in view {
                if key as! String == "graph" {
                    for g in getElemetArrayFromValue(child) as! [[String: AnyObject]] {
                        let index = (g["__index"] as! NSNumber).integerValue
                        
                        if let graph = handleGraph(g) {
                            views[index] = graph
                        }
                        else {
                            deleteIndices.append(index)
                        }
                    }
                }
                else if key as! String == "value" {
                    for g in getElemetArrayFromValue(child) as! [[String: AnyObject]] {
                        let index = (g["__index"] as! NSNumber).integerValue
                        
                        if let graph = handleValue(g) {
                            views[index] = graph
                        }
                        else {
                            deleteIndices.append(index)
                        }
                    }
                }
                else if key as! String == "edit" {
                    for g in getElemetArrayFromValue(child) as! [[String: AnyObject]] {
                        let index = (g["__index"] as! NSNumber).integerValue
                        
                        if let graph = handleEdit(g) {
                            views[index] = graph
                        }
                        else {
                            deleteIndices.append(index)
                        }
                    }
                }
                else if key as! String == "info" {
                    for g in getElemetArrayFromValue(child) as! [[String: AnyObject]] {
                        let index = (g["__index"] as! NSNumber).integerValue
                        
                        if let graph = handleInfo(g) {
                            views[index] = graph
                        }
                        else {
                            deleteIndices.append(index)
                        }
                    }
                }
            }
            
            if deleteIndices.count > 0 {
                views.removeAtIndices(deleteIndices)
            }
            
            let viewDescriptor = ExperimentViewCollectionDescriptor(label: label, translation: translation, views: views as! [ViewDescriptor])
            
            viewDescriptors.append(viewDescriptor)
        }
        
        return (viewDescriptors.count > 0 ? viewDescriptors : nil)
    }
}
