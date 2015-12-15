//
//  ExperimentIconParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 15.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import UIKit

final class ExperimentIconParser: ExperimentMetadataParser {
    let data: AnyObject
    
    required init(_ data: AnyObject) {
        self.data = data
    }
    
    func parse() -> ExperimentIcon? {
        if let icon = data as? String {
            return ExperimentIcon(string: icon, image: nil)
        }
        else if let icon = data as? NSDictionary {
            let attributes = icon[XMLDictionaryAttributesKey] as! [String: String]
            
            let string = icon[XMLDictionaryTextKey] as! String
            
            if stringFromXML(attributes, key: "format", defaultValue: "string") == "base64" {
                let data = NSData(base64EncodedString: string, options: NSDataBase64DecodingOptions())!
                let image = UIImage(data: data)
                
                return ExperimentIcon(string: nil, image: image)
            }
            else {
                return ExperimentIcon(string: string, image: nil)
            }
        }
        
        return nil
    }
}

