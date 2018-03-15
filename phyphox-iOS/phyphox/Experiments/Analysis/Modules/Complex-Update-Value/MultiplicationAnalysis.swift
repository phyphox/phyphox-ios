//
//  MultiplicationAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import Accelerate

final class MultiplicationAnalysis: ExperimentComplexUpdateValueAnalysis {
    
    override func update() {
        updateAllWithMethod({ (inputs) -> ValueSource in
            var main = inputs.first!
            
            for (i, input) in inputs.enumerated() {
                if i > 0 {
                    main = self.multiplyValueSources(main, b: input)
                }
            }
            
            return main
            },  priorityInputKey: nil)
    }
    
    func multiplyValueSources(_ a: ValueSource, b: ValueSource) -> ValueSource {
        if let scalarA = a.scalar, let scalarB = b.scalar { // scalar*scalar
            let result = scalarA*scalarB
            
            return ValueSource(scalar: result)
        }
        else if var scalar = a.scalar, let vector = b.vector { // scalar*vector
            var out = vector
            
            vDSP_vsmulD(vector, 1, &scalar, &out, 1, vDSP_Length(out.count))
            
            return ValueSource(vector: out)
        }
        else if let vector = a.vector, var scalar = b.scalar { // vector*scalar
            var out = vector
            
            vDSP_vsmulD(vector, 1, &scalar, &out, 1, vDSP_Length(out.count))
            
            return ValueSource(vector: out)
        }
        else if let vectorA = a.vector, let vectorB = b.vector { // vector*vector
            var out = vectorA
            
            vDSP_vmulD(vectorA, 1, vectorB, 1, &out, 1, vDSP_Length(out.count))
            
            return ValueSource(vector: out)
        }
        
        fatalError("Invalid value sources")
    }
}
