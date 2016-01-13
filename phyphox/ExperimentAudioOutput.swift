//
//  ExperimentAudioOutput.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentAudioOutput {
    let sampleRate: UInt
    let loop: Bool
    let dataSource: DataBuffer
    
    init(sampleRate: UInt, loop: Bool, dataSource: DataBuffer) {
        self.sampleRate = sampleRate
        self.loop = loop
        self.dataSource = dataSource
    }
}
