//
//  helper.swift
//  phyphox
//
//  Created by Sebastian Staacks on 12.04.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation

public func localize(_ key: String) -> String {
    let fallback = "en"
    
    let fallbackBundle = Bundle.main.path(forResource: fallback, ofType: "lproj")
    let fallbackString = fallbackBundle != nil ? Bundle(path: fallbackBundle!)?.localizedString(forKey: key, value: key, table: nil) : nil
    
    return Bundle.main.localizedString(forKey: key, value: fallbackString, table: nil)
    
}
