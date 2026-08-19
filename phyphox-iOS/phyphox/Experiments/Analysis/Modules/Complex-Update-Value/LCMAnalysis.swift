//
//  LCMAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

//The domain of lcm is non-negative integers: fractional values are rounded half away from zero
//like the formula language's round, while negative inputs, non-finite inputs and values beyond
//UInt.max yield NaN instead of trapping in the UInt conversion. lcm(0,x) is 0 by the usual
//convention, including lcm(0,0) (formerly a 0/0 trap), and a product overflowing UInt yields
//NaN instead of trapping.
func lcmOfDoubles(_ a: Double, _ b: Double) -> Double {
    guard a.isFinite && b.isFinite && a >= 0 && b >= 0 else { return Double.nan }
    let ra = a.rounded(.toNearestOrAwayFromZero)
    let rb = b.rounded(.toNearestOrAwayFromZero)
    guard ra < 0x1p64 && rb < 0x1p64 else { return Double.nan }
    let u = UInt(ra)
    let v = UInt(rb)
    if u == 0 || v == 0 {
        return 0.0
    }
    //u/gcd is exact, so this is the smallest intermediate; overflow here means the lcm itself
    //does not fit
    let (result, overflow) = (u / gcd(u, v)).multipliedReportingOverflow(by: v)
    return overflow ? Double.nan : Double(result)
}

final class LCMAnalysis: ExperimentComplexUpdateValueAnalysis {
    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [
            AnalysisIOSlot(name: "value", asRequired: false, repeatOffset: 0, valueAllowed: true, emptyAllowed: false, minCount: 2, maxCount: 2)
        ], outputs: [
            AnalysisIOSlot(name: "lcm", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
        ])
    }
    
    override func update() {
        updateAllWithMethod({ inputs -> ValueSource in
            var main = inputs.first!
            
            for (i, input) in inputs.enumerated() {
                if i > 0 {
                    main = self.lcmValueSources(main, b: input)
                }
            }
            
            
            return main
            }, priorityInputKey: nil)
    }
    
    func lcmValueSources(_ a: ValueSource, b: ValueSource) -> ValueSource {
        if let scalarA = a.scalar, let scalarB = b.scalar { // lcm(scalar,scalar)
            return ValueSource(scalar: lcmOfDoubles(scalarA, scalarB))
        }
        else if let scalar = a.scalar, let vector = b.vector { // lcm(scalar,vector)
            return ValueSource(vector: vector.map { lcmOfDoubles(scalar, $0) })
        }
        else if let vector = a.vector, let scalar = b.scalar { // lcm(vector,scalar)
            return ValueSource(vector: vector.map { lcmOfDoubles(scalar, $0) })
        }
        else if let vectorA = a.vector, let vectorB = b.vector { // lcm(vector,vector)
            return ValueSource(vector: vectorA.enumerated().map { lcmOfDoubles(vectorB[$0.offset], $0.element) })
        }

        fatalError("Invalid value sources")
    }
}
