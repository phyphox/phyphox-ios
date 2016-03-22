//
//  ExperimentAudioInput.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentAudioInput : NSObject, EZMicrophoneDelegate {
    let sampleRate: UInt
    let outBuffers: [DataBuffer]
    
    var microphone: EZMicrophone!
    
    init(sampleRate: UInt, outBuffers: [DataBuffer]) {
        self.sampleRate = sampleRate
        self.outBuffers = outBuffers
        
        super.init()
    }
    
    func startRecording() {
        if microphone == nil {
            microphone = EZMicrophone(delegate: self, withAudioStreamBasicDescription: EZAudioUtilities.monoFloatFormatWithSampleRate(Float(sampleRate)))
        }
        
        microphone.startFetchingAudio()
    }
    
    func stopRecording() {
        microphone.stopFetchingAudio()
    }
    
    @objc func microphone(microphone: EZMicrophone!, hasAudioReceived buffer: UnsafeMutablePointer<UnsafeMutablePointer<Float>>, withBufferSize bufferSize: UInt32, withNumberOfChannels numberOfChannels: UInt32) {
        let array: [Double] = Array(UnsafeBufferPointer(start: buffer.memory, count: Int(bufferSize))).map { (fl) -> Double in
            return Double(fl)
        }
        
        for out in outBuffers {
            out.appendFromArray(array)
        }
    }
}
