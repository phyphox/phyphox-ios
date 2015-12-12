//
//  Constants.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

func stringToBool(string: String) -> Bool {
    if string == "1" || string.lowercaseString == "true" || string.lowercaseString == "yes" {
        return true
    }
    
    return false
}
