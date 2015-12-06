//
//  RampGeneratorAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class RampGeneratorAnalysis: ExperimentAnalysis {
    private var start = "0"
    private var stop = "100"
    private var length = "-1"
    
    func setParameters(start: String?, stop: String?, length: String?) {
        if start != nil {
            self.start = start!
        }
        if stop != nil {
            self.stop = stop!
        }
        if length != nil {
            self.length = length!
        }
    }
    
    override func update() {
        let vStart = getSingleValueFromUserString(start)!
        let vStop = getSingleValueFromUserString(stop)!
        var vLength = UInt64(getSingleValueFromUserString(length)!)
        
        outputs.first!.clear()
        
        if vLength < 0 {
            vLength = outputs.first!.size
        }
        
        for i in 0...vLength-1 {
            outputs.first!.append(vStart+(vStop-vStart)/Double((vLength-1)*i))
        }
    }
}
