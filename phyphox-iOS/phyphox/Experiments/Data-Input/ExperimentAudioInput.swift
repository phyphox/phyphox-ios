//
//  ExperimentAudioInput.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation
import AVFoundation

struct ExperimentAudioInput: Equatable {
    let sampleRate: UInt
    let outBuffer: DataBuffer
    let backBuffer: DataBuffer
    let appendData: Bool
    let sampleRateInfoBuffer: DataBuffer?
    
    init(sampleRate: UInt, outBuffer: DataBuffer, sampleRateInfoBuffer: DataBuffer?, appendData: Bool) {
        self.sampleRate = sampleRate
        self.outBuffer = outBuffer
        self.backBuffer = try! DataBuffer(name: "", size: outBuffer.size, baseContents: [], static: false)
        self.sampleRateInfoBuffer = sampleRateInfoBuffer
        self.appendData = appendData
    }
}
