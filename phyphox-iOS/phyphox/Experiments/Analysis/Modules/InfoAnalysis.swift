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
    private static let batteryLevelOutSlot = AnalysisIOSlot(name: "batteryLevel", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let wifiSignalStrengthOutSlot = AnalysisIOSlot(name: "wifiSignalStrength", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let systemVolumeOutSlot = AnalysisIOSlot(name: "systemVolume", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let batteryVoltageOutSlot = AnalysisIOSlot(name: "batteryVoltage", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let batteryCurrentOutSlot = AnalysisIOSlot(name: "batteryCurrent", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let batteryTemperatureOutSlot = AnalysisIOSlot(name: "batteryTemperature", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [], outputs: [Self.batteryLevelOutSlot, Self.wifiSignalStrengthOutSlot, Self.systemVolumeOutSlot, Self.batteryVoltageOutSlot, Self.batteryCurrentOutSlot, Self.batteryTemperatureOutSlot])
    }

    private var batteryLevelOutput: ExperimentAnalysisDataOutput?
    private var systemVolumeOutput: ExperimentAnalysisDataOutput?
    
    // wifi signal strength is not implemented in iOS as done in android, because of lack of general purposed API to get signal strength
    // https://developer.apple.com/forums/thread/721067
    // private var wifiSignalStrengthOutput: ExperimentAnalysisDataOutput?
    
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {

        let io = try Self.mapIO(inputs: inputs, outputs: outputs)
        batteryLevelOutput = io.output(Self.batteryLevelOutSlot)
        systemVolumeOutput = io.output(Self.systemVolumeOutSlot)

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
