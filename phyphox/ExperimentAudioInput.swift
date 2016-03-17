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
    
    let microphone: EZMicrophone = EZMicrophone()
    
    init(sampleRate: UInt, outBuffers: [DataBuffer]) {
        self.sampleRate = sampleRate
        self.outBuffers = outBuffers
        
        super.init()
        
        microphone.delegate = self
    }
    
    func startRecording() {
        microphone.startFetchingAudio()
    }
    
    func stopRecording() {
        microphone.stopFetchingAudio()
    }
    
    @objc func microphone(microphone: EZMicrophone!, hasAudioReceived buffer: UnsafeMutablePointer<UnsafeMutablePointer<Float>>, withBufferSize bufferSize: UInt32, withNumberOfChannels numberOfChannels: UInt32) {
        
    }
    
    
}
