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
        for output in outputs {
            if output.clear {
                output.buffer!.replaceValues([timestamp])
            }
            else {
                output.buffer!.append(timestamp)
            }
        }
    }
}
