//
//  PTFile.swift
//  phyphox
//
//  Created by Jonas Gessner on 07.04.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

final class PTFile {
    class func stringWithContentsOfFile(_ path: String) -> String {
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
    
    class func contentsOfFile(_ path: String) -> [(String, String)] {
        let plain = try! String(contentsOfFile: path, encoding: String.Encoding.utf8)
        
        let components = plain.components(separatedBy: "\n-->\n")
        
        var results = [(String, String)]()
        
        for component in components {
            let comps = component.components(separatedBy: "::\n")
            
            if comps.count != 2 || component.count == 0 {
                continue
            }
            
            results.append((comps.first!, comps.last!))
        }
        
        return results
    }
}
