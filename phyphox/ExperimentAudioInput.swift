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
    let outBuffers: [DataBuffer]
    
    init(sampleRate: UInt, outBuffers: [DataBuffer]) {
        self.sampleRate = sampleRate
        self.outBuffers = outBuffers
    }
}
