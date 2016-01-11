//
//  ExperimentAnalysisGroup.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

class ExperimentAnalysisGroup {
    let analyses: [ExperimentAnalysis]
    
    let sleep: Double
    let onUserInput: Bool
    
    init(analyses: [ExperimentAnalysis], sleep: Double, onUserInput: Bool) {
        self.analyses = analyses
        
        self.sleep = sleep
        self.onUserInput = onUserInput
    }
}
