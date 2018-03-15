//
//  ExperimentAudioOutput.swift
//  phyphox
//
//  Created by Jonas Gessner on 22.03.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation
import AVFoundation

final class ExperimentAudioOutput {
    let dataSource: DataBuffer
    let loop: Bool
    let sampleRate: UInt
    
    init(sampleRate: UInt, loop: Bool, dataSource: DataBuffer) {
        self.dataSource = dataSource;
        self.sampleRate = sampleRate;
        self.loop = loop;
    }
}
