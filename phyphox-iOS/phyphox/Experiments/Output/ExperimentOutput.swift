//
//  ExperimentOutput.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

final class ExperimentOutput {
    /**
     The only available output is audio at the moment
     */
    let audioOutput: ExperimentAudioOutput?
    
    init(audioOutput: ExperimentAudioOutput?) {
        self.audioOutput = audioOutput
    }
}
