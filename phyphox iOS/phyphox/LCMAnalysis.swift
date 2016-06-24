//
//  LCMAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

func lcm(u: UInt, _ v: UInt) -> UInt {
    return (u*v)/gcd(u, v)
}

final class LCMAnalysis: ExperimentComplexUpdateValueAnalysis {
    
    override func update() {
        updateAllWithMethod({ inputs -> ValueSource in
            var main = inputs.first!
            
            for (i, input) in inputs.enumerate() {
                if i > 0 {
                    main = self.lcmValueSources(main, b: input)
                }
            }
            
            
            return main
            }, priorityInputKey: nil)
    }
    
    func lcmValueSources(a: ValueSource, b: ValueSource) -> ValueSource {
        if let scalarA = a.scalar, let scalarB = b.scalar { // lcm(scalar,scalar)
            if !isfinite(scalarA) || !isfinite(scalarB) {
                return ValueSource(scalar: Double.NaN)
            }
            
            let result = Double(lcm(UInt(scalarA), UInt(scalarB)))
            
            return ValueSource(scalar: result)
        }
        else if let scalar = a.scalar, let vector = b.vector { // lcm(scalar,vector)
            var out = [Double]()
            out.reserveCapacity(vector.count)
            
            for val in vector {
                if !isfinite(val) || !isfinite(scalar) {
                    out.append(Double.NaN)
                }
                else {
                    out.append(Double(lcm(UInt(scalar), UInt(val))))
                }
            }
            
            return ValueSource(vector: out)
        }
        else if let vector = a.vector, let scalar = b.scalar { // lcm(vector,scalar)
            var out = [Double]()
            out.reserveCapacity(vector.count)
            
            for val in vector {
                if !isfinite(val) || !isfinite(scalar) {
                    out.append(Double.NaN)
                }
                else {
                    out.append(Double(lcm(UInt(scalar), UInt(val))))
                }
            }
            
            return ValueSource(vector: out)
        }
        else if let vectorA = a.vector, let vectorB = b.vector { // lcm(vector,vector)
            var out = [Double]()
            out.reserveCapacity(vectorA.count)
            
            for (i, val) in vectorA.enumerate() {
                let valB = vectorB[i]
                
                if !isfinite(val) || !isfinite(valB) {
                    out.append(Double.NaN)
                }
                else {
                     out.append(Double(lcm(UInt(valB), UInt(val))))
                }
               
            }
            
            return ValueSource(vector: out)
        }
        
        fatalError("Invalid value sources")
    }
}
