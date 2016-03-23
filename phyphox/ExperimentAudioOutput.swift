//
//  ExperimentAudioOutput.swift
//  phyphox
//
//  Created by Jonas Gessner on 22.03.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentAudioOutput {
    let dataSource: DataBuffer
    let loop: Bool
    let sampleRate: UInt
    
    var channel: AEBlockChannel!
    
    private var stopPlayback = false
    private var lastIndex = 0
    private var playing = false
    
    init(sampleRate: UInt, loop: Bool, dataSource: DataBuffer) {
        self.dataSource = dataSource;
        self.sampleRate = sampleRate;
        self.loop = loop;
        
        defer {
            channel = AEBlockChannel { [unowned self] (timestamp: UnsafePointer<AudioTimeStamp>, frames: UInt32, data: UnsafeMutablePointer<AudioBufferList>) in
                if dataSource.count == 0 {
                    return
                }
                
                if self.stopPlayback {
                    self.pause()
                    return
                }
                
                let buffer = unsafeBitCast(UnsafeMutableAudioBufferListPointer(data).first!.mData, UnsafeMutablePointer<Float>.self)
                
                let valueArray = dataSource.toArray().map({ (dbl) -> Float in
                    return Float(dbl)
                })
                
                for i in 0..<Int(frames) {
                    if !self.loop {
                        let index = self.lastIndex+i
                        
                        if index < valueArray.count {
                            buffer[i] = valueArray[index]
                        }
                        else {
                            buffer[i] = 0
                            self.stopPlayback = true
                        }
                    }
                    else {
                        let index = (self.lastIndex+i) % valueArray.count
                        
                        buffer[i] = valueArray[index]
                    }
                }
                
                self.lastIndex = (self.lastIndex+Int(frames)-1) % valueArray.count
            }
        }
    }
    
    func play() {
        if !playing {
            playing = true
            stopPlayback = false
            ExperimentManager.sharedInstance().audioController.addChannels([channel])
        }
    }
    
    func pause() {
        if playing {
            lastIndex = 0
            ExperimentManager.sharedInstance().audioController.removeChannels([channel])
            playing = false
        }
    }
    
}
