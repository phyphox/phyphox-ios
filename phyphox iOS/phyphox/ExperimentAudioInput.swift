//
//  ExperimentAudioInput.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

private let audioInputQueue = DispatchQueue(label: "de.rwth-aachen.phyphox.audioInput", attributes: [])

final class ExperimentAudioInput {
    let sampleRate: UInt
    var buffer: DataBuffer?
    let outBuffers: [DataBuffer]
    
    fileprivate var receiver: AEBlockAudioReceiver!
    
    init(sampleRate: UInt, outBuffers: [DataBuffer]) {
        self.sampleRate = sampleRate
        self.outBuffers = outBuffers

        if (outBuffers.count == 0) {
            buffer = nil
            return
        }
        
        buffer = DataBuffer(name: "", size: outBuffers[0].size, vInit: [])
        
        
        
/*        defer {
            let block = AEBlockAudioReceiverBlock({ (source: UnsafeMutablePointer<Void>?, time: UnsafePointer<AudioTimeStamp>?, frames: UInt32, audio: UnsafeMutablePointer<AudioBufferList>?) -> Void in
                audioInputQueue.async(execute: {
                    autoreleasepool(invoking: {
                        var array = [Float](repeating: 0.0, count: Int(frames))
                        
                        var arrayPointer: UnsafeMutablePointer? = UnsafeMutablePointer<Float>(mutating: array)
                        
                        AEFloatConverterToFloat(ExperimentManager.sharedInstance().floatConverter, audio, &arrayPointer, frames)
                        
                        let final = array.map({Double.init($0)})
                        
                        self.buffer!.appendFromArray(final)
                    })
                })
            })
            
            receiver = AEBlockAudioReceiver(block: block)
        }
 */
    }
    
    func receiveData() {
        if self.outBuffers.count == 0 {
            return
        }
        
        for out in self.outBuffers {
            out.replaceValues(self.buffer!.toArray())
        }
        self.buffer!.clear()
    }
    
    func startRecording(_ experiment: Experiment) {
        ExperimentManager.sharedInstance().audioController.addInputReceiver(receiver)
    }
    
    func stopRecording(_ experiment: Experiment) {
        ExperimentManager.sharedInstance().audioController.removeInputReceiver(receiver)
    }
}
