//
//  SinhAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 06.10.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation
import Accelerate

final class SinhAnalysis: UpdateValueAnalysis {
    
    override func update() {
        updateAllWithMethod { array -> [Double] in
            var results = array

            vvsinh(&results, array, [Int32(array.count)])
            
            return results
        }
    }
}
