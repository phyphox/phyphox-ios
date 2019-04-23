//
//  LCMAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

func lcm(_ u: UInt, _ v: UInt) -> UInt {
    return (u*v)/gcd(u, v)
}

final class LCMAnalysis: ExperimentComplexUpdateValueAnalysis {
    
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
            if !scalarA.isFinite || !scalarB.isFinite {
                return ValueSource(scalar: Double.nan)
            }
            
            let result = Double(lcm(UInt(scalarA), UInt(scalarB)))
            
            return ValueSource(scalar: result)
        }
        else if let scalar = a.scalar, let vector = b.vector { // lcm(scalar,vector)
            var out = [Double]()
            out.reserveCapacity(vector.count)
            
            for val in vector {
                if !val.isFinite || !scalar.isFinite {
                    out.append(Double.nan)
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
                if !val.isFinite || !scalar.isFinite {
                    out.append(Double.nan)
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
            
            for (i, val) in vectorA.enumerated() {
                let valB = vectorB[i]
                
                if !val.isFinite || !valB.isFinite {
                    out.append(Double.nan)
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
