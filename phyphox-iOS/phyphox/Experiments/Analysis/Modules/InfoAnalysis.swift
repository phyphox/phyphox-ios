//
//  InfoAnalysis.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 07.03.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

import Foundation
import NetworkExtension
import AVFAudio

final class InfoAnalysis: AutoClearingExperimentAnalysisModule {
    
    private var batteryLevelOutput: ExperimentAnalysisDataOutput?
    private var systemVolumeOutput: ExperimentAnalysisDataOutput?
    
    // wifi signal strength is not implemented in iOS as done in android, because of lack of general purposed API to get signal strength
    // https://developer.apple.com/forums/thread/721067
    // private var wifiSignalStrengthOutput: ExperimentAnalysisDataOutput?
    
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
      
        for output in outputs {
            if output.asString == "batteryLevel" {
                batteryLevelOutput = output
                
            }  else if output.asString == "systemVolume" {
                systemVolumeOutput = output
            }
        }
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        if let output = batteryLevelOutput {
            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.append(getBatteryLevel())
            }
        }
        
        if let output = systemVolumeOutput {
            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.append(getSystemVolume())
            }
        }
    }
    
    func getBatteryLevel() -> Double {
        UIDevice.current.isBatteryMonitoringEnabled = true

        return Double(UIDevice.current.batteryLevel) * 100.0
    }
    
    
    func getSystemVolume() -> Double {
        let audioSession = AVAudioSession.sharedInstance()
        var volume: Float?
        do{
            try audioSession.setActive(true)
            volume = audioSession.outputVolume
        } catch {
            print("Error Setting Up Audio Session")
        }
        
        return Double(volume ?? 0.0) * 100.0
    }
    
}
