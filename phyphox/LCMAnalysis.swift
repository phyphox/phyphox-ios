//
//  LCMAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class LCMAnalysis: ExperimentComplexUpdateValueAnalysis {
    
    override func update() {
        updateWithMethod(nil, outerMethod: { (currentValue, values) -> Double in
            var a = round(values.first!)
            var b = round(values[1])
            
            let a0 = a;
            let b0 = b;
            
            //Euclid's algorithm (modern iterative version)
            while (b > 0) {
                let tmp = b;
                b = a % b;
                a = tmp;
            }
            
            return a0*(b0/a)
            }, neutralElement: 0.0, priorityInputKey: nil)
    }
}
