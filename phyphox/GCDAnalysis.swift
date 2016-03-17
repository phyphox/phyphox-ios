//
//  GCDAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class GCDAnalysis: ExperimentComplexUpdateValueAnalysis {
    
    class func gcd(u: UInt, v: UInt) -> UInt {
        // simple cases (termination)
        if (u == v) {
            return u;
        }
        
        if (u == 0) {
            return v;
        }
        
        if (v == 0) {
            return u;
        }
        
        // look for factors of 2
        if (~u & 1) == 1 {// u is even
            if (v & 1) == 1 {// v is odd
                return gcd(u >> 1, v: v);
            }
            else {// both u and v are even
                return gcd(u >> 1, v: v >> 1) << 1;
            }
        }
        
        if (~v & 1) == 1 { // u is odd, v is even
            return gcd(u, v: v >> 1);
        }
        
        // reduce larger argument
        if (u > v) {
            return gcd((u - v) >> 1, v: v);
        }
        
        return gcd((v - u) >> 1, v: u);
    }
    
    override func update() {
        updateAllWithMethod({ (inputs: [[Double]]) -> [Double] in
            var main = inputs.first!
            
            for (i, input) in inputs.enumerate() {
                if i > 0 {
                    var temp: [Double] = []
                    
                    for (j, value) in main.enumerate() {
                        temp.append(Double(self.dynamicType.gcd(UInt(value), v: UInt(input[j]))))
                    }
                    
                    main = temp
                }
            }
            
            
            return main
            }, priorityInputKey: nil)
    }
}
