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
                    var pointer = UnsafeMutablePointer<Float>.alloc(Int(frames))
                    
                    defer {
                        pointer.destroy()
                        pointer.dealloc(Int(frames))
                    }
                    
                    AEFloatConverterToFloat(ExperimentManager.sharedInstance().floatConverter, data, &pointer, frames)
                    
                    let array: [Double] = Array(UnsafeMutableBufferPointer(start: pointer, count: Int(frames))).map { (fl) -> Double in
                        return Double(fl)
                    }
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        for out in self.outBuffers {
                            out.appendFromArray(array)
                        }
                    }
                })
            }
        }
    }
    
    func startRecording(experiment: Experiment) {
        ExperimentManager.sharedInstance().audioController.addInputReceiver(receiver)

//        Novocaine.audioManager().inputBlock = { (data, numFrames, numChannels) in
//            
//            var num = 0
//            
//            let array: [Double] = Array(UnsafeMutableBufferPointer(start: data, count: Int(numFrames))).map { (fl) -> Double in
//                return Double(fl)
//                }.filter({ (element) -> Bool in
//                    let ok = (num % Int(numChannels)) == 0
//                    if ok {
//                        num = 0
//                    }
//                    
//                    num += 1
//                    
//                    return ok
//                }) //filter to only get frames from one channel
//            
//            dispatch_async(dispatch_get_main_queue()) {
//                for out in self.outBuffers {
//                    out.appendFromArray(array)
//                }
//            }
//        }
//        
//        Novocaine.audioManager().play()
        
//        if microphone == nil {
//            microphone = EZMicrophone(delegate: self, withAudioStreamBasicDescription: EZAudioUtilities.monoFloatFormatWithSampleRate(Float(sampleRate)))
//        }
//        
//        microphone.startFetchingAudio()
    }
    
    func stopRecording(experiment: Experiment) {
        ExperimentManager.sharedInstance().audioController.removeInputReceiver(receiver)
//        Novocaine.audioManager().pause()
//        microphone.stopFetchingAudio()
    }
    
//    @objc func microphone(microphone: EZMicrophone!, hasAudioReceived buffer: UnsafeMutablePointer<UnsafeMutablePointer<Float>>, withBufferSize bufferSize: UInt32, withNumberOfChannels numberOfChannels: UInt32) {
//        
////        let array: [Double] = Array(UnsafeMutableBufferPointer(start: buffer.memory, count: Int(bufferSize))).map { (fl) -> Double in
////            return Double(fl)
////        }
////        
////        autoreleasepool {
////            let monoChannel = buffer[0]
////            
////            var array = [Double]()
////            array.reserveCapacity(Int(bufferSize))
////            
////            for i in 0..<Int(bufferSize) {
////                let value = Double(monoChannel[i])
////                array.append(value)
////            }
////            
////            dispatch_async(dispatch_get_main_queue()) {
////                for out in self.outBuffers {
////                    out.appendFromArray(array)
////                }
////            }
////        }
//    }
}
