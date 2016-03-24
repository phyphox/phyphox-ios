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
    
    var receiver: AEBlockAudioReceiver!
    
    init(sampleRate: UInt, outBuffers: [DataBuffer]) {
        self.sampleRate = sampleRate
        self.outBuffers = outBuffers
        
        defer {
            receiver = AEBlockAudioReceiver { [unowned self] (from: UnsafeMutablePointer<Void>, timestamp: UnsafePointer<AudioTimeStamp>, frames: UInt32, data: UnsafeMutablePointer<AudioBufferList>) in
                autoreleasepool({
                    var array = [Float](count: Int(frames), repeatedValue: 0.0)
                    
                    var arrayPointer = UnsafeMutablePointer<Float>(array)
                    
                    defer {
                        arrayPointer.destroy()
                    }
                    
                    AEFloatConverterToFloat(ExperimentManager.sharedInstance().floatConverter, data, &arrayPointer, frames)
                    
                    let final = array.map{ Double($0) }
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        for out in self.outBuffers {
                            out.appendFromArray(final)
                        }
                    }
                })
            }
        }
    }
    
    func startRecording(experiment: Experiment) {
        ExperimentManager.sharedInstance().audioController.addInputReceiver(receiver)
    }
    
    func stopRecording(experiment: Experiment) {
        ExperimentManager.sharedInstance().audioController.removeInputReceiver(receiver)
    }
}
