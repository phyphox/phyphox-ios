//
//  ExperimentExportParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

final class ExperimentExportParser: ExperimentMetadataParser {
    let sets: [NSDictionary]?
    
    required init(_ data: NSDictionary) {
        sets = getElementsWithKey(data, key: "set") as! [NSDictionary]?
    }
    
    func parse(buffers: [String: DataBuffer], translation: ExperimentTranslationCollection?) -> ExperimentExport? {
        if sets == nil {
            return nil
        }
        
        var final: [ExperimentExportSet] = []
        final.reserveCapacity(sets!.count)
        
        for set in sets! {
            let attributes = set[XMLDictionaryAttributesKey] as! [String: String]
            
            let name = attributes["name"]!
            
            let datas = getElementsWithKey(set, key: "data") as! [[String: AnyObject]]
            
            var buffs = [(name: String, buffer: DataBuffer)]()
            
            for data in datas {
                let attributes = data[XMLDictionaryAttributesKey] as! [String: String]
                
                let name = attributes["name"]!
                
                let bufferName = data[XMLDictionaryTextKey] as! String
                let buffer = buffers[bufferName]!
                
                buffs.append((name, buffer))
            }
            
            assert(buffs.count > 0, "No export data sources")
            
            let processed = ExperimentExportSet(name: name, data: buffs, translation: translation)
            
            final.append(processed)
        }
        
        return ExperimentExport(sets: final)
    }
}
