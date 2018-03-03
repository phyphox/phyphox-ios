//
//  ExperimentAudioInput.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation
import AVFoundation

final class ExperimentAudioInput {
    let sampleRate: UInt
    let outBuffer: DataBuffer
    let sampleRateInfoBuffer: DataBuffer?
    
    init(sampleRate: UInt, outBuffer: DataBuffer, sampleRateInfoBuffer: DataBuffer?) {
        self.sampleRate = sampleRate
        self.outBuffer = outBuffer
        self.sampleRateInfoBuffer = sampleRateInfoBuffer
    }
}
