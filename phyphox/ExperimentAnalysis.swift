//
//  ExperimentAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentAnalysis : DataBufferObserver {
    let analyses: [ExperimentAnalysisModule]
    
    let sleep: Double
    let onUserInput: Bool
    
    init(analyses: [ExperimentAnalysisModule], sleep: Double, onUserInput: Bool) {
        self.analyses = analyses
        
        self.sleep = sleep
        self.onUserInput = onUserInput
        
        registerForUpdates()
    }
    
    private func registerForUpdates() {
        for analysis in analyses {
            for input in analysis.inputs {
                if input.buffer != nil {
                    input.buffer!.addObserver(self)
                }
            }
        }
    }
    
    func dataBufferUpdated(buffer: DataBuffer) {
        setNeedsUpdate()
    }
    
    private var scheduleUpdate = false
    private var busy = false
    
    /**
     Schedules an update.
    */
    func setNeedsUpdate() {
        if busy {
            scheduleUpdate = true
        }
        else {
            busy = true
            
            after(0.1, closure: { () -> Void in
                self.update()
                
                self.busy = false
                
                if self.scheduleUpdate {
                    self.scheduleUpdate = false
                    self.setNeedsUpdate()
                }
            })
        }
    }
    
    /**
     Updates immediately. Don't call this method directly, schedule updates via `setNeedsUpdate()`
     */
    func update() {
        print("update")
        for analysis in analyses {
            analysis.setNeedsUpdate()
        }
    }
}
