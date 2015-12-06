//
//  DifferentiationAnylsis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class DifferentiationAnylsis: ExperimentAnalysis {
    
    override func update() {
        var v: Double
        var last: Double!
        
        outputs.first!.clear()
        
        let iterator = getBufferForKey(inputs.first!)?.generate()
        
        if iterator == nil {
            return
        }
        
        var first = true
        
        while let next = iterator!.next() {
            if first {
                last = next
                first = false
                continue
            }
            
            v = next
            outputs.first!.append(v-last)
            last = v
        }
    }
}
