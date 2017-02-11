//
//  ExperimentAudioInput.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

private let audioInputQueue = dispatch_queue_create("de.rwth-aachen.phyphox.audioInput", DISPATCH_QUEUE_SERIAL)

final class ExperimentAudioInput {
    let sampleRate: UInt
    var buffer: DataBuffer?
    let outBuffers: [DataBuffer]
    
    private var receiver: AEBlockAudioReceiver!
    
    init(sampleRate: UInt, outBuffers: [DataBuffer]) {
        self.sampleRate = sampleRate
        self.outBuffers = outBuffers

        if (outBuffers.count == 0) {
            buffer = nil
            return
        }
        
        buffer = DataBuffer(name: "", size: outBuffers[0].size, vInit: Double.NaN)
        
        defer {
            receiver = AEBlockAudioReceiver { [unowned self] (from: UnsafeMutablePointer<Void>, timestamp: UnsafePointer<AudioTimeStamp>, frames: UInt32, data: UnsafeMutablePointer<AudioBufferList>) in
                dispatch_async(audioInputQueue, {
                    autoreleasepool({
                        var array = [Float](count: Int(frames), repeatedValue: 0.0)
                        
                        var arrayPointer = UnsafeMutablePointer<Float>(array)
                        
                        AEFloatConverterToFloat(ExperimentManager.sharedInstance().floatConverter, data, &arrayPointer, frames)
                        
                        let final = array.map(Double.init)
                        
                        self.buffer!.appendFromArray(final)
                    })
                })
            }
        }
    }
    
    func receiveData() {
        if self.outBuffers.count == 0 {
            return
        }
        
        for out in self.outBuffers {
            out.appendFromArray(self.buffer!.toArray())
        }
        self.buffer!.clear()
    }
    
    func startRecording(experiment: Experiment) {
        ExperimentManager.sharedInstance().audioController.addInputReceiver(receiver)
    }
    
    func stopRecording(experiment: Experiment) {
        ExperimentManager.sharedInstance().audioController.removeInputReceiver(receiver)
    }
}
