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
    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [
            AnalysisIOSlot(name: "y", asRequired: false, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 1, maxCount: 1),
            AnalysisIOSlot(name: "x", asRequired: false, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 1, maxCount: 1)
        ], outputs: [
            AnalysisIOSlot(name: "atan2", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
        ])
    }
    var deg: Bool //internal for the unit tests, which cannot construct attributes
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
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
            })
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
            let f = self.deg ? 180.0/Double.pi : 1.0
            
            return ValueSource(vector: vector.map { atan2(scalarA, $0) * f })
        }
        else if let vector = a.vector, let scalarB = b.scalar { // vector*scalar
            let f = self.deg ? 180.0/Double.pi : 1.0
            
            return ValueSource(vector: vector.map { atan2($0, scalarB) * f })
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
