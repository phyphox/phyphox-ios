//
//  SubtractionAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import Accelerate

final class SubtractionAnalysis: ExperimentComplexUpdateValueAnalysis {
    
    override func update() {
        updateAllWithMethod({ (inputs) -> ValueSource in
            var main = inputs.first!
            
            for (i, input) in inputs.enumerated() {
                if i > 0 {
                    main = self.subtractValueSources(main, b: input)
                }
            }
            
            return main
            },  priorityInputKey: "minuend")
    }
    
    func subtractValueSources(_ a: ValueSource, b: ValueSource) -> ValueSource {
        if let scalarA = a.scalar, let scalarB = b.scalar { // scalar-scalar
            let result = scalarA-scalarB
            
            return ValueSource(scalar: result)
        }
        else if var scalar = a.scalar, let vector = b.vector { // scalar-vector
            var out = vector
            
            var mult = -1.0
            
            //scalar-vector = -vector+scalar
            vDSP_vsmsaD(vector, 1, &mult, &scalar, &out, 1, vDSP_Length(out.count))
            
            return ValueSource(vector: out)
        }
        else if let vector = a.vector, var scalar = b.scalar { // vector-scalar
            var out = vector
            
            scalar = -scalar
            
            vDSP_vsaddD(vector, 1, &scalar, &out, 1, vDSP_Length(out.count))
            
            return ValueSource(vector: out)
        }
        else if let vectorA = a.vector, let vectorB = b.vector { // vector-vector
            var out = vectorA
            
            vDSP_vsubD(vectorB, 1, vectorA, 1, &out, 1, vDSP_Length(out.count))
            
            return ValueSource(vector: out)
        }
        
        fatalError("Invalid value sources")
    }
}
