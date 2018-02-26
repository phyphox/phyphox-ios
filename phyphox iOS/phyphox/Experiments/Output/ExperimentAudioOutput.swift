//
//  ExperimentAudioOutput.swift
//  phyphox
//
//  Created by Jonas Gessner on 22.03.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation
import AVFoundation

private let audioOutputQueue = DispatchQueue(label: "de.rwth-aachen.phyphox.audioOutput", attributes: DispatchQueue.Attributes.concurrent)

final class ExperimentAudioOutput {
    let dataSource: DataBuffer
    let loop: Bool
    let sampleRate: UInt
    
    init(sampleRate: UInt, loop: Bool, dataSource: DataBuffer) {
        self.dataSource = dataSource;
        self.sampleRate = sampleRate;
        self.loop = loop;
    }
    
    func play() {
        ExperimentManager.sharedInstance().audioEngine.play()
    }
    
    func stop() {
        ExperimentManager.sharedInstance().audioEngine.stop()
    }
    
}
