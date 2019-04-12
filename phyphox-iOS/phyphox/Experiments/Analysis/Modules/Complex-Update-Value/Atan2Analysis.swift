//
//  Atan2Analysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 06.10.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation
import Accelerate

final class Atan2Analysis: ExperimentComplexUpdateValueAnalysis {
    private let deg: Bool
    
    required init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: AttributeContainer) throws {
        let attributes = additionalAttributes.attributes(keyedBy: String.self)

        deg = try attributes.optionalValue(for: "deg") ?? false
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        updateAllWithMethod({ (inputs) -> ValueSource in
            var main = inputs.first!
            
            for (i, input) in inputs.enumerated() {
                if i > 0 {
                    main = self.Atan2ValueSources(main, b: input)
                }
            }
            
            return main
            },  priorityInputKey: "y")
    }
    
    func Atan2ValueSources(_ a: ValueSource, b: ValueSource) -> ValueSource {
        if let scalarA = a.scalar, let scalarB = b.scalar { // scalar*scalar
            var result = atan2(scalarA, scalarB)
            
            if self.deg {
                let f = 180.0/Double.pi
                result = result * f
            }
            
            return ValueSource(scalar: result)
        }
        else if let scalarA = a.scalar, let vector = b.vector { // scalar*vector
            let scalarB = vector[0]
            var result = atan2(scalarA, scalarB)
            
            if self.deg {
                let f = 180.0/Double.pi
                result = result * f
            }
            
            return ValueSource(scalar: result)
        }
        else if let vector = a.vector, let scalarB = b.scalar { // vector*scalar
            let scalarA = vector[0]
            var result = atan2(scalarA, scalarB)
            
            if self.deg {
                let f = 180.0/Double.pi
                result = result * f
            }
            
            return ValueSource(scalar: result)
        }
        else if let vectorA = a.vector, let vectorB = b.vector { // vector*vector
            var results = vectorA
            
            let countA = vectorA.count
            let countB = vectorB.count
            let count = countA < countB ? countA : countB
            
            vvatan2(&results, vectorA, vectorB, [Int32(count)])
            
            if self.deg {
                var f = 180.0/Double.pi
                vDSP_vsmulD(results, 1, &f, &results, 1, vDSP_Length(results.count))
            }
            
            return ValueSource(vector: results)
        }
        
        fatalError("Invalid value sources")
    }
}
