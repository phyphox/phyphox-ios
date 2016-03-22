//
//  AudioOutput.swift
//  phyphox
//
//  Created by Jonas Gessner on 22.03.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation
import EZAudioiOS

class AudioOutput : NSObject, EZOutputDataSource {
    var output: EZOutput!
    let dataSource: DataBuffer
    let loop: Bool
    let sampleRate: UInt
    
    init(sampleRate: UInt, loop: Bool, dataSource: DataBuffer) {
        let inputFormat = EZAudioUtilities.monoFloatFormatWithSampleRate(Float(sampleRate))
        
        self.dataSource = dataSource;
        self.sampleRate = sampleRate;
        self.loop = loop;
        
        super.init()
        
        output = EZOutput(dataSource: self, inputFormat: inputFormat)
    }
    
    @objc func output(output: EZOutput!, shouldFillAudioBufferList audioBufferList: UnsafeMutablePointer<AudioBufferList>, withNumberOfFrames frames: UInt32, timestamp: UnsafePointer<AudioTimeStamp>) -> OSStatus {
        let buffer = UnsafeMutableAudioBufferListPointer(audioBufferList).first!.mData
        
//        if (_stopPlayback) {
//            _stopPlayback = NO;
//            [self pause];
//            return -1;
//        }
        
        if (dataSource.count == 0) {
            return noErr;
        }
        
        let array = dataSource.toArray()
        
        let buffer: [Double] = []
        
        if !loop {
            buffer.assignFrom(&array, count: array.count)
        }
        
        for frame in 0..<frames {
            if (!loop) {
                if (frame < UInt32(array.count)) {
                    memset(buffer, array[frame], 32)
                }
                else {
                    _stopPlayback = YES;
                    break;
                }
            }
            else {
                NSUInteger index = (_lastIndex+frame) % array.count;
                
                buffer[frame] = array[index].doubleValue;
            }
        }
        
        _lastIndex = (_lastIndex+frames-1) % array.count;
        
        return noErr;
    }
}
