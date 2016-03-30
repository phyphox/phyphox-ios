//
//  ABSAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import Accelerate

final class ABSAnalysis: UpdateValueAnalysis {
    
    override func update() {
        updateAllWithMethod { array -> [Double] in
            var results = array
            vvfabs(&results, array, [Int32(array.count)])
            
            return results
        }
    }
}
