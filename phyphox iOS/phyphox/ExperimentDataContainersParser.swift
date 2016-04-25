//
//  ExperimentDataContainersParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

final class ExperimentDataContainersParser: ExperimentMetadataParser {
    var containers: [AnyObject]?
    
    required init(_ data: NSDictionary) {
        containers = getElementsWithKey(data, key: "container")
    }
    
    enum ExperimentDataContainerType {
        case Buffer
        case Unknown
    }
    
    func dataContainerTypeFromXML(xml: [String: AnyObject]?, key: String) -> ExperimentDataContainerType {
        let str = stringFromXML(xml, key: key, defaultValue: "buffer")
        
        if str == "buffer" {
            return .Buffer
        }
        else {
            print("Error! Invalid data container type: \(str)")
            return .Unknown
        }
    }
    
    func parse() -> ([String: DataBuffer]?, [DataBuffer]?) {
        if let cont = containers {
            var buffers: [String: DataBuffer] = [:]
            var ordered: [DataBuffer] = []
            
            ordered.reserveCapacity(cont.count)
            
            for container in cont {
                var name: String!
                
                var containerType = ExperimentDataContainerType.Buffer //Default
                var bufferSize = 1 //Default
                var stat = false //Default
                
                if let str = container as? String {
                    name = str
                }
                else if let dict = container as? NSDictionary {
                    if let attributes = dict[XMLDictionaryAttributesKey] as? [String: String] {
                        bufferSize = intTypeFromXML(attributes, key: "size", defaultValue: 1)
                        stat = boolFromXML(attributes, key: "static", defaultValue: false)
                        
                        containerType = dataContainerTypeFromXML(attributes, key: "type")
                    }
                    
                    name = dict[XMLDictionaryTextKey] as! String
                }
                
                if containerType == .Buffer && name.characters.count > 0 {
                    let buffer = DataBuffer(name: name, size: bufferSize)
                    buffer.staticBuffer = stat
                    
                    buffers[name] = buffer
                    ordered.append(buffer)
                }
            }
            
            if buffers.count > 0 {
                return (buffers, ordered)
            }
        }
        
        return (nil, nil)
    }
}
