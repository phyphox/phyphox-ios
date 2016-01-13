//
//  ExperimentAudioInput.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentAudioInput {
    let sampleRate: UInt
    let outBuffer: DataBuffer
    
    init(sampleRate: UInt, outBuffer: DataBuffer) {
        self.sampleRate = sampleRate
        self.outBuffer = outBuffer
    }
}
