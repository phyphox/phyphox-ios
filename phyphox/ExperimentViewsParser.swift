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
            
            let name = attributes["name"]!
            
            var graphDescriptors: [GraphViewDescriptor] = []
            
            if let graphs = getElementsWithKey(view, key: "graph") as! [NSDictionary]? {
                for graph in graphs {
                    let attributes = graph[XMLDictionaryAttributesKey] as! [String: String]
                    
                    let graphLabel = attributes["label"]!
                    let xLabel = attributes["labelX"]!
                    let yLabel = attributes["labelY"]!
                    
                    var partialUpdate = false
                    
                    if let partialUpdateStr = attributes["partialUpdate"] {
                        partialUpdate = stringToBool(partialUpdateStr)
                    }
                    
                    var xInputBuffer: DataBuffer?
                    var yInputBuffer: DataBuffer?
                    
                    if let inputs = getElementsWithKey(graph, key: "input") as! [NSDictionary]? {
                        for input in inputs {
                            let attributes = input[XMLDictionaryAttributesKey] as! [String: String]
                            
                            //let type = "buffer" //Default
                            
                            if let customType = attributes["type"] {
                                if customType != "buffer" {
                                    print("Error! Invalid input type: \(customType)")
                                    continue
                                }
                            }
                            
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
                    
                    let graphDescriptor = GraphViewDescriptor(label: graphLabel, xLabel: xLabel, yLabel: yLabel, partialUpdate: partialUpdate, xInputBuffer: xInputBuffer, yInputBuffer: yInputBuffer)
                    
                    graphDescriptors.append(graphDescriptor)
                }
            }
            
            let viewDescriptor = ExperimentViewDescriptor(name: name, graphs: (graphDescriptors.count > 0 ? graphDescriptors : nil))
            
            viewDescriptors.append(viewDescriptor)
        }
        
        return (viewDescriptors.count > 0 ? viewDescriptors : nil)
    }
}
