//
//  TimerAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 02.04.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

final class TimerAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        outputs.first!.buffer!.append(timestamp)
    }
}
