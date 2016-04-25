//
//  PTFile.swift
//  phyphox
//
//  Created by Jonas Gessner on 07.04.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

final class PTFile {
    class func stringWithContentsOfFile(path: String) -> String {
        var str = ""
        var empty = true
        
        for (title, body) in contentsOfFile(path) {
            if !empty {
                str += "\n\n\n"
            }
            
            str += title + ":\n" + body
            
            empty = false
        }
        
        return str
    }
    
    class func contentsOfFile(path: String) -> [(String, String)] {
        let plain = try! String(contentsOfFile: path, encoding: NSUTF8StringEncoding)
        
        let components = plain.componentsSeparatedByString("\n-->\n")
        
        var results = [(String, String)]()
        
        for component in components {
            let comps = component.componentsSeparatedByString("::\n")
            
            if comps.count != 2 || component.characters.count == 0 {
                continue
            }
            
            results.append((comps.first!, comps.last!))
        }
        
        return results
    }
}
