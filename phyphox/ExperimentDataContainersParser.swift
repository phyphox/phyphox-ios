//
//  ExperimentDataContainersParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import UIKit

enum ExperimentDataContainerType {
    case Buffer
}

final class ExperimentDataContainersParser: ExperimentMetadataParser {
    var containers: [AnyObject]?
    
    required init(_ data: NSDictionary) {
        containers = getElementsWithKey(data, key: "container")
    }
    
    func parse() -> [String: DataBuffer]? {
        if let cont = containers {
            var buffers: [String: DataBuffer] = [:]
            
            for container in cont {
                //let type = ExperimentDataContainerType.Buffer
                
                var name: String!
                var bufferSize = 0
                
                if let str = container as? String {
                    name = str
                }
                else if let dict = container as? NSDictionary {
                    if let attributes = dict[XMLDictionaryAttributesKey] {
                        if let size = attributes["size"] as! String? {
                            bufferSize = Int(size)!
                        }
                        
                        if let t = attributes["type"] as! String? {
                            if (t != "buffer") { //Unknown container type
                                continue;
                            }
                        }
                    }
                    
                    name = dict[XMLDictionaryTextKey] as! String
                }
                
                if name.characters.count > 0 {
                    let buffer = DataBuffer(name: name, size: bufferSize)
                    buffers[name] = buffer
                }
            }
            
            if buffers.count > 0 {
                return buffers
            }
        }
        
        return nil
    }
}
