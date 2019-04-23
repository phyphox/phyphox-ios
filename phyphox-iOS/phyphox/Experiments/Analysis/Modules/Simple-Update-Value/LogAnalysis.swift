//
//  LogAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 28.05.17.
//  Copyright © 2017 RWTH Aachen. All rights reserved.
//

import Foundation
import Accelerate

final class LogAnalysis: UpdateValueAnalysis {
    
    override func update() {
        updateAllWithMethod { array -> [Double] in
            var results = array
            
            vvlog(&results, array, [Int32(array.count)])
            
            return results
        }
    }
}
