//
//  ExperimentExportParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentExportParser: ExperimentMetadataParser {
    let sets: [NSDictionary]?
    
    required init(_ data: NSDictionary) {
        sets = getElementsWithKey(data, key: "set") as! [NSDictionary]?
    }
    
    func parse(buffers: [String: DataBuffer]) -> ExperimentExport? {
        if sets == nil {
            return nil
        }
        
        var final: [ExperimentExportSet] = []
        
        for set in sets! {
            let attributes = set[XMLDictionaryAttributesKey] as! [String: String]
            
            let name = attributes["name"]!
            
            let datas = getElementsWithKey(set, key: "data")!
            
            let dict = MutableOrderedDictionary()
            
            for data in datas {
                let attributes = data[XMLDictionaryAttributesKey] as! [String: String]
                
                let name = attributes["name"]!
                
                let bufferName = data[XMLDictionaryTextKey] as! String
                let buffer = buffers[bufferName]!
                
                dict.setObject(buffer, forKey: name)
            }
            
            assert(dict.count > 0, "No export data sources")
            
            let processed = ExperimentExportSet(name: name, data: dict)
            
            final.append(processed)
        }
        
        return ExperimentExport(sets: final)
    }
}
