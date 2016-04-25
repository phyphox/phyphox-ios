//
//  TanAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation
import Accelerate

final class TanAnalysis: UpdateValueAnalysis {
    
    override func update() {
        updateAllWithMethod { array -> [Double] in
            var results = array
            vvtan(&results, array, [Int32(array.count)])
            
            return results
        }
    }
}
