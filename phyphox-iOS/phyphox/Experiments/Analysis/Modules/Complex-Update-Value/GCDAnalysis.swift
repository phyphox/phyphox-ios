//
//  GCDAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

func gcd(_ u: UInt, _ v: UInt) -> UInt {
    // simple cases (termination)
    if (u == v) {
        return u
    }
    
    if (u == 0) {
        return v
    }
    
    if (v == 0) {
        return u
    }
    
    // look for factors of 2
    if (~u & 1) == 1 {// u is even
        if (v & 1) == 1 {// v is odd
            return gcd(u >> 1, v)
        }
        else {// both u and v are even
            return gcd(u >> 1, v >> 1) << 1
        }
    }
    
    if (~v & 1) == 1 { // u is odd, v is even
        return gcd(u, v >> 1)
    }
    
    // reduce larger argument
    if (u > v) {
        return gcd((u - v) >> 1, v)
    }

    return gcd((v - u) >> 1, u)
}

//The domain of gcd is non-negative integers: fractional values are rounded half away from zero
//like the formula language's round, while negative inputs, non-finite inputs and values beyond
//UInt.max yield NaN instead of trapping in the UInt conversion.
func gcdOfDoubles(_ a: Double, _ b: Double) -> Double {
    guard a.isFinite && b.isFinite && a >= 0 && b >= 0 else { return Double.nan }
    let ra = a.rounded(.toNearestOrAwayFromZero)
    let rb = b.rounded(.toNearestOrAwayFromZero)
    guard ra < 0x1p64 && rb < 0x1p64 else { return Double.nan }
    return Double(gcd(UInt(ra), UInt(rb)))
}

final class GCDAnalysis: ExperimentComplexUpdateValueAnalysis {
    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [
            AnalysisIOSlot(name: "value", asRequired: false, repeatOffset: 0, valueAllowed: true, emptyAllowed: false, minCount: 2, maxCount: 2)
        ], outputs: [
            AnalysisIOSlot(name: "gcd", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
        ])
    }
    
    override func update() {
        updateAllWithMethod({ inputs -> ValueSource in
            var main = inputs.first!
            
            for (i, input) in inputs.enumerated() {
                if i > 0 {
                    main = self.gcdValueSources(main, b: input)
                }
            }
            
            
            return main
            }, priorityInputKey: nil)
    }
    
    func gcdValueSources(_ a: ValueSource, b: ValueSource) -> ValueSource {
        if let scalarA = a.scalar, let scalarB = b.scalar { // gcd(scalar,scalar)
            return ValueSource(scalar: gcdOfDoubles(scalarA, scalarB))
        }
        else if let scalar = a.scalar, let vector = b.vector { // gcd(scalar,vector)
            return ValueSource(vector: vector.map { gcdOfDoubles(scalar, $0) })
        }
        else if let vector = a.vector, let scalar = b.scalar { // gcd(vector,scalar)
            return ValueSource(vector: vector.map { gcdOfDoubles(scalar, $0) })
        }
        else if let vectorA = a.vector, let vectorB = b.vector { // gcd(vector,vector)
            return ValueSource(vector: vectorA.enumerated().map { gcdOfDoubles(vectorB[$0.offset], $0.element) })
        }

        fatalError("Invalid value sources")
    }

}
