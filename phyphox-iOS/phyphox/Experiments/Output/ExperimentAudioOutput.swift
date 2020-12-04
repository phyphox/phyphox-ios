//
//  ExperimentAudioOutput.swift
//  phyphox
//
//  Created by Jonas Gessner on 22.03.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation
import AVFoundation

enum AudioParameter: Equatable {
    case buffer(buffer: DataBuffer)
    case value(value: Double?)

    func getValue() -> Double? {
        switch self {
        case .buffer(buffer: let buffer):
            return buffer.last
        case .value(value: let value):
            return value
        }
    }

    var isBuffer: Bool {
        switch self {
        case .buffer(buffer: _):
            return true
        case .value(value: _):
            return false
        }
    }
}

struct ExperimentAudioOutputTone: Equatable {
    let frequency: AudioParameter
    let amplitude: AudioParameter
    let duration: AudioParameter
}

struct ExperimentAudioOutputNoise: Equatable {
    let amplitude: AudioParameter
    let duration: AudioParameter
}

struct ExperimentAudioOutput: Equatable {
    let loop: Bool
    let normalize: Bool
    let sampleRate: UInt
    
    let directSource: DataBuffer?
    let tones: [ExperimentAudioOutputTone]
    let noise: ExperimentAudioOutputNoise?
    
    init(sampleRate: UInt, loop: Bool, normalize: Bool, directSource: DataBuffer?, tones: [ExperimentAudioOutputTone], noise: ExperimentAudioOutputNoise?) {
        self.sampleRate = sampleRate
        self.loop = loop
        self.normalize = normalize
        
        self.directSource = directSource
        self.tones = tones
        self.noise = noise
    }
}
