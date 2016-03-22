//
//  LCMAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import Surge

final class LCMAnalysis: ExperimentComplexUpdateValueAnalysis {
    
    class func lcm(u: UInt, v: UInt) -> UInt {
        return (u*v)/GCDAnalysis.gcd(u, v: v)
    }
    
    override func update() {
        updateAllWithMethod({ (inputs: [[Double]]) -> [Double] in
            var main = inputs.first!
            
            for (i, input) in inputs.enumerate() {
                if i > 0 {
                    var temp: [Double] = []
                    
                    for (j, value) in main.enumerate() {
                        if isinf(input[j]) || isnan(input[j]) {
                            continue
                        }
                        temp.append(Double(self.dynamicType.lcm(UInt(value), v: UInt(input[j]))))
                    }
                    
                    main = temp
                }
            }
            
            
            return main
            }, priorityInputKey: nil)
    }
}
