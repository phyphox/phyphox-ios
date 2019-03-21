//
//  PowerAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import Accelerate

final class PowerAnalysis: ExperimentComplexUpdateValueAnalysis {
    
    override func update() {
        updateAllWithMethod({ (inputs) -> ValueSource in
            var main = inputs.first!
            
            for (i, input) in inputs.enumerated() {
                if i > 0 {
                    main = self.powValueSources(main, b: input)
                }
            }
            
            return main
            },  priorityInputKey: "base")
    }
    
    func powValueSources(_ a: ValueSource, b: ValueSource) -> ValueSource {
        if let scalarA = a.scalar, let scalarB = b.scalar { // scalar^scalar
            return ValueSource(scalar: pow(scalarA, scalarB))
        } else if let scalar = a.scalar, let vector = b.vector { // scalar^vector
            return ValueSource(vector: vector.map({return pow(scalar, $0)}))
        } else if let vector = a.vector, let scalar = b.scalar { // vector^scalar
            return ValueSource(vector: vector.map({return pow($0, scalar)}))
        } else if let vectorA = a.vector, let vectorB = b.vector { // vector^vector
            return ValueSource(vector: zip(vectorA, vectorB).map({return pow($0, $1)}))
        }
        
        fatalError("Invalid value sources")
        
        //Cannot use vvpow since it does not handle negative exponents
        /*
        if let scalarA = a.scalar, let scalarB = b.scalar { // scalar^scalar
            let result = pow(scalarA, scalarB)
            
            return ValueSource(scalar: result)
        }
        else if let scalar = a.scalar, let vector = b.vector { // scalar^vector
            var out = vector
            
            let vecScalar = [Double](repeating: scalar, count: out.count)
            
            var count = Int32(out.count)
            
            vvpow(&out, vecScalar, vector, &count)
            
            return ValueSource(vector: out)
        }
        else if let vector = a.vector, var scalar = b.scalar { // vector^scalar
            var out = vector
            
            var count = Int32(out.count)
            
            vvpows(&out, &scalar, vector, &count)
            
            return ValueSource(vector: out)
        }
        else if let vectorA = a.vector, let vectorB = b.vector { // vector^vector
            var out = vectorA
            
            var count = Int32(out.count)
            
            vvpow(&out, vectorA, vectorB, &count)
            
            return ValueSource(vector: out)
        }
        
        fatalError("Invalid value sources")
         */
    }
}
