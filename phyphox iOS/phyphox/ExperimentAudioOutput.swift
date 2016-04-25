//
//  ExperimentAudioOutput.swift
//  phyphox
//
//  Created by Jonas Gessner on 22.03.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//


import Foundation
import AVFoundation

private let audioOutputQueue = dispatch_queue_create("de.rwth-aachen.phyphox.audioOutput", DISPATCH_QUEUE_CONCURRENT)

final class ExperimentAudioOutput {
    let dataSource: DataBuffer
    let loop: Bool
    let sampleRate: UInt
    
    private var pcmPlayer: AVAudioPlayerNode!
    private var engine: AVAudioEngine!
    private var pcmBuffer: AVAudioPCMBuffer!
    
    private var playing = false
    
    private let format: AVAudioFormat
    
    private var stateToken: NSUUID?
    
    init(sampleRate: UInt, loop: Bool, dataSource: DataBuffer) {
        self.dataSource = dataSource;
        self.sampleRate = sampleRate;
        self.loop = loop;
        
        var audioDescription = monoFloatFormatWithSampleRate(Double(sampleRate))
        
        format = AVAudioFormat(streamDescription: &audioDescription)
    }
    
    func play() {
        if !playing || !self.dataSource.stateTokenIsValid(self.stateToken) {
            playing = true
            
            dispatch_sync(audioOutputQueue, {
                if self.engine == nil {
                    self.pcmPlayer = AVAudioPlayerNode()
                    self.engine = AVAudioEngine()
                    
                    self.engine.attachNode(self.pcmPlayer)
                    self.engine.connect(self.pcmPlayer, to: self.engine.mainMixerNode, format: self.format)
                }
                
                //If a buffer gets played and paused repeatedly (like the sonar) but the content that is played is always the same the buffer doesn't need to be created again.
                if self.pcmBuffer == nil || !self.dataSource.stateTokenIsValid(self.stateToken) {
                    var source = self.dataSource.toArray().map { Float($0) }
                    self.stateToken = self.dataSource.getStateToken()
                    
                    if self.pcmPlayer.playing {
                        self.pcmBuffer = nil
                        self.pcmPlayer.stop()
                    }
                    
                    self.pcmBuffer = AVAudioPCMBuffer(PCMFormat: self.format, frameCapacity: UInt32(source.count))
                    self.pcmBuffer.floatChannelData[0].assignFrom(&source, count: source.count)
                    self.pcmBuffer.frameLength = UInt32(source.count)
                }
                
                do {
                    if !self.engine.running {
                        try self.engine.start()
                    }
                    
                    weak var bufferRef = self.pcmBuffer
                    
                    self.pcmPlayer.play()
                    
                    self.pcmPlayer.scheduleBuffer(self.pcmBuffer, atTime: nil, options: (self.loop ? .Loops : []), completionHandler: { [unowned self] in
                        if bufferRef == self.pcmBuffer { //bufferRef != self.pcmBuffer <=> pcmBuffer was cancelled and recreated because the data source changed, playback should not be cancelled.
                            self.pause()
                        }
                    })
                    
                    
                }
                catch let error {
                    print("Player error: \(error)")
                }
            })
        }
    }
    
    func pause() {
        if playing {
            self.pcmPlayer.stop()
            self.engine.stop()
            
            playing = false
        }
    }
    
    func destroyAudioEngine() {
        pause()
        
        stateToken = nil
        pcmBuffer = nil
        
        engine.detachNode(pcmPlayer)
        pcmPlayer = nil
        engine = nil
    }
}
