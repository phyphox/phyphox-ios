//
//  ExperimertFlashlightOutput.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 23.03.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

enum FlashlightParameter: Equatable {
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

class ExperimentFlashlightOutput {
    let intensity: FlashlightParameter
    let frequency: FlashlightParameter
    
    init(intensity: FlashlightParameter, frequency: FlashlightParameter) {
        self.intensity = intensity
        self.frequency = frequency
    }
}

