//
//  CosAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import Accelerate

final class CosAnalysis: UpdateValueAnalysis {
    private let deg: Bool
    
    required init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: AttributeContainer) throws {
        let attributes = additionalAttributes.attributes(keyedBy: String.self)

        deg = try attributes.optionalValue(for: "deg") ?? false
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        updateAllWithMethod { array -> [Double] in
            var results = array
            if self.deg {
                var f = Double.pi/180.0
                vDSP_vsmulD(array, 1, &f, &results, 1, vDSP_Length(array.count))
            }
            vvcos(&results, results, [Int32(results.count)])
            
            return results
        }
    }
}

