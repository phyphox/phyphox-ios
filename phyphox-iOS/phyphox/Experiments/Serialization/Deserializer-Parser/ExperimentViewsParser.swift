//
//  ExperimentViewsParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
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
    
    func stringToGraphAxis(_ string: String) -> GraphAxis? {
        if string.lowercased() == "x" {
            return .x
        }
        else if string.lowercased() == "y" {
            return .y
        }
        
        return nil
    }
    
    func parse(_ buffers: [String: DataBuffer], translation: ExperimentTranslationCollection?) throws -> [ExperimentViewCollectionDescriptor]? {
        if views == nil {
            return nil
        }
        
        var viewDescriptors: [ExperimentViewCollectionDescriptor] = []
        
        for view in views! {
            let attributes = view[XMLDictionaryAttributesKey] as! [String: String]
            
            let label = attributes["label"]!
            var views = [ViewDescriptor!](repeating: nil, count: (view["__count"] as! NSNumber).intValue)
            
            func handleEdit(_ edit: [String: AnyObject]) throws -> EditViewDescriptor? {
                let attributes = edit[XMLDictionaryAttributesKey] as! [String: String]
                
                let label = attributes["label"]!
                
                let signed = boolFromXML(attributes as [String : AnyObject], key: "signed", defaultValue: true)
                
                let decimal = boolFromXML(attributes as [String : AnyObject], key: "decimal", defaultValue: true)
                
                let unit = attributes["unit"]
                
                let factor = floatTypeFromXML(attributes as [String : AnyObject], key: "factor", defaultValue: 1.0)
                
                let min = floatTypeFromXML(attributes as [String : AnyObject], key: "min", defaultValue: -Double.infinity)
                let max = floatTypeFromXML(attributes as [String : AnyObject], key: "max", defaultValue: Double.infinity)
                
                let defaultValue = floatTypeFromXML(attributes as [String : AnyObject], key: "default", defaultValue: 0.0)
                
                var outputBuffer: DataBuffer? = nil
                
                if let output = getElementsWithKey(edit as NSDictionary, key: "output") {
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
                    throw SerializationError.invalidExperimentFile(message: "No output buffer for edit view.")
                }
                
                outputBuffer!.attachedToTextField = true
                
                if outputBuffer!.last == nil {
                    outputBuffer!.append(defaultValue) //Set the default value.
                }
                
                return EditViewDescriptor(label: label, translation: translation, signed: signed, decimal: decimal, unit: unit, factor: factor, min: min, max: max, defaultValue: defaultValue, buffer: outputBuffer!)
            }
            
            func handleValue(_ value: [String: AnyObject]) throws -> ValueViewDescriptor? {
                let attributes = value[XMLDictionaryAttributesKey] as! [String: String]
                
                let label = attributes["label"]!
                
                let scientific = boolFromXML(attributes as [String : AnyObject], key: "scientific", defaultValue: false)
                let precision = intTypeFromXML(attributes as [String : AnyObject], key: "precision", defaultValue: 2)
                
                let unit = attributes["unit"]
                
                let factor = floatTypeFromXML(attributes as [String : AnyObject], key: "factor", defaultValue: 1.0)
                
                let size = floatTypeFromXML(attributes as [String : AnyObject], key: "size", defaultValue: 1.0)
                
                var inputBuffer: DataBuffer? = nil
                
                if let input = getElementsWithKey(value as NSDictionary, key: "input") {
                    let first = input.first!
                    
                    if first is NSDictionary {
                        let bufferName = (first as! NSDictionary)[XMLDictionaryTextKey] as! String
                        
                        inputBuffer = buffers[bufferName]
                    }
                    else if first is NSString {
                        inputBuffer = buffers[first as! String]
                    }
                }
                
                var mappings: [(min: Double, max: Double, str: String)] = []
                
                if let maps = getElementsWithKey(value as NSDictionary, key: "map") {
                    for map in maps {
                    
                        if map is NSDictionary {
                            let str = (map as! NSDictionary)[XMLDictionaryTextKey] as! String
                            let mapAttrs = (map as! NSDictionary)[XMLDictionaryAttributesKey] as! [String : AnyObject]
                            let min = floatTypeFromXML(mapAttrs, key: "min", defaultValue: -Double.infinity)
                            let max = floatTypeFromXML(mapAttrs, key: "max", defaultValue: +Double.infinity)
                            mappings.append((min: min, max: max, str: str))
                        } else {
                            let str = map as! String
                            mappings.append((min: -Double.infinity, max: +Double.infinity, str: str))
                        }
                    }
                }
                
                if inputBuffer == nil {
                    throw SerializationError.invalidExperimentFile(message: "No input buffer for value view.")
                }
                
                return ValueViewDescriptor(label: label, translation: translation, size: size, scientific: scientific, precision: precision, unit: unit, factor: factor, buffer: inputBuffer!, mappings: mappings)
            }
            
            func handleGraph(_ graph: [String: AnyObject]) throws -> GraphViewDescriptor? {
                let attributes = graph[XMLDictionaryAttributesKey] as! [String: String]
                
                let label = attributes["label"]!
                
                let aspectRatio = CGFloatFromXML(attributes as [String : AnyObject], key: "aspectRatio", defaultValue: 2.5)
                let dots = stringFromXML(attributes as [String : AnyObject], key: "style", defaultValue: "line") == "dots"
                let partialUpdate = boolFromXML(attributes as [String : AnyObject], key: "partialUpdate", defaultValue: false)
                let forceFullDataset = boolFromXML(attributes as [String : AnyObject], key: "forceFullDataset", defaultValue: false)
                let history = intTypeFromXML(attributes as [String : AnyObject], key: "history", defaultValue: UInt(1))
                let lineWidth = CGFloatFromXML(attributes as [String : AnyObject], key: "lineWidth", defaultValue: 1.0)
                let color = try UIColorFromXML(attributes as [String : AnyObject], key: "color", defaultValue: kHighlightColor)
                
                let logX = boolFromXML(attributes as [String : AnyObject], key: "logX", defaultValue: false)
                let logY = boolFromXML(attributes as [String : AnyObject], key: "logY", defaultValue: false)
                let xPrecision = UInt(intTypeFromXML(attributes as [String : AnyObject], key: "xPrecision", defaultValue: 3))
                let yPrecision = UInt(intTypeFromXML(attributes as [String : AnyObject], key: "yPrecision", defaultValue: 3))
                
                let scaleMinX: GraphViewDescriptor.scaleMode
                switch stringFromXML(attributes as [String : AnyObject], key: "scaleMinX", defaultValue: "auto") {
                    case "auto": scaleMinX = GraphViewDescriptor.scaleMode.auto
                    case "extend": scaleMinX = GraphViewDescriptor.scaleMode.extend
                    case "fixed": scaleMinX = GraphViewDescriptor.scaleMode.fixed
                    default:
                        scaleMinX = GraphViewDescriptor.scaleMode.auto
                        throw SerializationError.invalidExperimentFile(message: "Unknown value for scaleMinX.")
                }
                let scaleMaxX: GraphViewDescriptor.scaleMode
                switch stringFromXML(attributes as [String : AnyObject], key: "scaleMaxX", defaultValue: "auto") {
                    case "auto": scaleMaxX = GraphViewDescriptor.scaleMode.auto
                    case "extend": scaleMaxX = GraphViewDescriptor.scaleMode.extend
                    case "fixed": scaleMaxX = GraphViewDescriptor.scaleMode.fixed
                    default:
                        scaleMaxX = GraphViewDescriptor.scaleMode.auto
                        throw SerializationError.invalidExperimentFile(message: "Error! Unknown value for scaleMaxX.")
                }
                let scaleMinY: GraphViewDescriptor.scaleMode
                switch stringFromXML(attributes as [String : AnyObject], key: "scaleMinY", defaultValue: "auto") {
                    case "auto": scaleMinY = GraphViewDescriptor.scaleMode.auto
                    case "extend": scaleMinY = GraphViewDescriptor.scaleMode.extend
                    case "fixed": scaleMinY = GraphViewDescriptor.scaleMode.fixed
                    default:
                        scaleMinY = GraphViewDescriptor.scaleMode.auto
                        throw SerializationError.invalidExperimentFile(message: "Error! Unknown value for scaleMinY.")
                }
                let scaleMaxY: GraphViewDescriptor.scaleMode
                switch stringFromXML(attributes as [String : AnyObject], key: "scaleMaxY", defaultValue: "auto") {
                    case "auto": scaleMaxY = GraphViewDescriptor.scaleMode.auto
                    case "extend": scaleMaxY = GraphViewDescriptor.scaleMode.extend
                    case "fixed": scaleMaxY = GraphViewDescriptor.scaleMode.fixed
                    default:
                        scaleMaxY = GraphViewDescriptor.scaleMode.auto
                        throw SerializationError.invalidExperimentFile(message: "Error! Unknown value for scaleMaxY.")
                }
                
                let minX = CGFloatFromXML(attributes as [String : AnyObject], key: "minX", defaultValue: 0.0)
                let maxX = CGFloatFromXML(attributes as [String : AnyObject], key: "maxX", defaultValue: 0.0)
                let minY = CGFloatFromXML(attributes as [String : AnyObject], key: "minY", defaultValue: 0.0)
                let maxY = CGFloatFromXML(attributes as [String : AnyObject], key: "maxY", defaultValue: 0.0)
                
                
                let xLabel = attributes["labelX"]!
                let yLabel = attributes["labelY"]!
                
                var xInputBuffer: DataBuffer?
                var yInputBuffer: DataBuffer?
                
                if let inputs = getElementsWithKey(graph as NSDictionary, key: "input") {
                    for input_ in inputs {
                        if let input = input_ as? [String: AnyObject] {
                            let attributes = input[XMLDictionaryAttributesKey] as! [String: AnyObject]
                            
                            let axisString = attributes["axis"] as! String
                            
                            let axis = stringToGraphAxis(axisString)
                            
                            if axis == nil {
                                throw SerializationError.invalidExperimentFile(message: "Error! Invalid graph axis: \(axisString)")
                            }
                            
                            let bufferName = input[XMLDictionaryTextKey] as! String
                            
                            let buffer = buffers[bufferName]
                            
                            if buffer == nil {
                                throw SerializationError.invalidExperimentFile(message: "Error! Unknown buffer name: \(bufferName)")
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
                    throw SerializationError.invalidExperimentFile(message: "Error! No Y axis input buffer!")
                }

                return GraphViewDescriptor(label: label, translation: translation, xLabel: xLabel, yLabel: yLabel, xInputBuffer: xInputBuffer, yInputBuffer: yInputBuffer!, logX: logX, logY: logY, xPrecision: xPrecision, yPrecision: yPrecision, scaleMinX: scaleMinX, scaleMaxX: scaleMaxX, scaleMinY: scaleMinY, scaleMaxY: scaleMaxY, minX: minX, maxX: maxX, minY: minY, maxY: maxY, aspectRatio: aspectRatio, drawDots: dots, partialUpdate: partialUpdate, forceFullDataset: forceFullDataset, history: history, lineWidth: lineWidth, color: color)
            }
            
            func handleInfo(_ info: [String: AnyObject]) -> InfoViewDescriptor? {
                let attributes = info[XMLDictionaryAttributesKey] as! [String: String]
                
                let label = attributes["label"]!
                
                return InfoViewDescriptor(label: label, translation: translation)
            }
            
            func handleSeparator(_ separator: [String: AnyObject]) throws -> SeparatorViewDescriptor? {
                let attributes = separator[XMLDictionaryAttributesKey] as! [String: String]
                
                let height = CGFloatFromXML(attributes as [String : AnyObject], key: "height", defaultValue: 0.1)
                let color = try UIColorFromXML(attributes as [String : AnyObject], key: "color", defaultValue: kBackgroundColor)
                
                
                return SeparatorViewDescriptor(height: height, color: color)
            }
            
            func handleButton(_ button: [String: AnyObject]) throws -> ButtonViewDescriptor? {
                let attributes = button[XMLDictionaryAttributesKey] as! [String: String]
                
                let label = attributes["label"]!
                var inputList : [ExperimentAnalysisDataIO] = []
                var outputList : [DataBuffer] = []
                
                if let inputs = getElementsWithKey(button as NSDictionary, key: "input") {
                    for input_ in inputs {
                        if let input = input_ as? [String: AnyObject] {
                            inputList.append(try ExperimentAnalysisDataIO(dictionary: input as NSDictionary, buffers: buffers))
                        } else {
                            inputList.append(ExperimentAnalysisDataIO(buffer: buffers[input_ as! String]!))
                        }
                    }
                }
                if let outputs = getElementsWithKey(button as NSDictionary, key: "output") {
                    for output in outputs {
                        if let bufferName = output as? String {
                            let buffer = buffers[bufferName]
                            
                            if buffer == nil {
                                throw SerializationError.invalidExperimentFile(message: "Error! Unknown buffer name: \(bufferName)")
                            }

                            outputList.append(buffer!)
                        }
                    }
                }
                
                return ButtonViewDescriptor(label: label, translation: translation, inputs: inputList, outputs: outputList)
            }
            
            var deleteIndices: [Int] = []
            
            for (key, child) in view {
                if key as! String == "graph" {
                    for g in getElemetArrayFromValue(child as AnyObject) as! [[String: AnyObject]] {
                        let index = (g["__index"] as! NSNumber).intValue
                        
                        if let graph = try handleGraph(g) {
                            views[index] = graph
                        }
                        else {
                            deleteIndices.append(index)
                        }
                    }
                }
                else if key as! String == "value" {
                    for g in getElemetArrayFromValue(child as AnyObject) as! [[String: AnyObject]] {
                        let index = (g["__index"] as! NSNumber).intValue
                        
                        if let graph = try handleValue(g) {
                            views[index] = graph
                        }
                        else {
                            deleteIndices.append(index)
                        }
                    }
                }
                else if key as! String == "edit" {
                    for g in getElemetArrayFromValue(child as AnyObject) as! [[String: AnyObject]] {
                        let index = (g["__index"] as! NSNumber).intValue
                        
                        if let graph = try handleEdit(g) {
                            views[index] = graph
                        }
                        else {
                            deleteIndices.append(index)
                        }
                    }
                }
                else if key as! String == "info" {
                    for g in getElemetArrayFromValue(child as AnyObject) as! [[String: AnyObject]] {
                        let index = (g["__index"] as! NSNumber).intValue
                        
                        if let info = handleInfo(g) {
                            views[index] = info
                        }
                        else {
                            deleteIndices.append(index)
                        }
                    }
                }
                else if key as! String == "separator" {
                    for g in getElemetArrayFromValue(child as AnyObject) as! [[String: AnyObject]] {
                        let index = (g["__index"] as! NSNumber).intValue
                        
                        if let sep = try handleSeparator(g) {
                            views[index] = sep
                        }
                        else {
                            deleteIndices.append(index)
                        }
                    }
                }
                else if key as! String == "button" {
                    for g in getElemetArrayFromValue(child as AnyObject) as! [[String: AnyObject]] {
                        let index = (g["__index"] as! NSNumber).intValue
                        
                        if let button = try handleButton(g) {
                            views[index] = button
                        }
                        else {
                            deleteIndices.append(index)
                        }
                    }
                }
                else if !(key as! String).hasPrefix("__") {
                    throw SerializationError.invalidExperimentFile(message: "Error! Unknown view element: \(key as! String)")
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
