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

private let audioOutputQueue = DispatchQueue(label: "de.rwth-aachen.phyphox.audioOutput", attributes: DispatchQueue.Attributes.concurrent)

final class ExperimentAudioOutput {
    let dataSource: DataBuffer
    let loop: Bool
    let sampleRate: UInt
    
    fileprivate var pcmPlayer: AVAudioPlayerNode!
    fileprivate var engine: AVAudioEngine!
    fileprivate var pcmBuffer: AVAudioPCMBuffer!
    
    fileprivate var playing = false
    
    fileprivate let format: AVAudioFormat
    
    fileprivate var stateToken: UUID?
    
    init(sampleRate: UInt, loop: Bool, dataSource: DataBuffer) {
        self.dataSource = dataSource;
        self.sampleRate = sampleRate;
        self.loop = loop;
        
        var audioDescription = monoFloatFormatWithSampleRate(Double(sampleRate))
        
        format = AVAudioFormat(streamDescription: &audioDescription)
    }
    
    @objc func audioEngineConfigurationChange(_ notification: Notification) -> Void {
        pause()
        play()
    }
    
    func play() {
        if !playing || !self.dataSource.stateTokenIsValid(self.stateToken) {
            playing = true
            
            audioOutputQueue.sync(execute: {
                if self.engine == nil {
                    self.pcmPlayer = AVAudioPlayerNode()
                    self.engine = AVAudioEngine()
                    
                    NotificationCenter.default.addObserver(self, selector: #selector(audioEngineConfigurationChange), name: NSNotification.Name.AVAudioEngineConfigurationChange, object: self.engine)
                    
                    self.engine.attach(self.pcmPlayer)
                    self.engine.connect(self.pcmPlayer, to: self.engine.mainMixerNode, format: self.format)
                }
                
                //If a buffer gets played and paused repeatedly (like the sonar) but the content that is played is always the same the buffer doesn't need to be created again.
                if self.pcmBuffer == nil || !self.dataSource.stateTokenIsValid(self.stateToken) {
                    var source = self.dataSource.toArray().map { Float($0) }
                    self.stateToken = self.dataSource.getStateToken() as UUID?
                    
                    if self.pcmPlayer.isPlaying {
                        self.pcmBuffer = nil
                        self.pcmPlayer.stop()
                    }
                    
                    if source.count == 0 {
                        //There is no data to play
                        self.engine.stop()
                        self.playing = false
                        return
                    }
                    
                    self.pcmBuffer = AVAudioPCMBuffer(pcmFormat: self.format, frameCapacity: UInt32(source.count))
                    self.pcmBuffer.floatChannelData?[0].assign(from: &source, count: source.count)
                    self.pcmBuffer.frameLength = UInt32(source.count)
                }
                
                do {
                    if !self.engine.isRunning {
                        try self.engine.start()
                    }
                    
                    weak var bufferRef = self.pcmBuffer
                    self.pcmPlayer.play()
                    self.pcmPlayer.scheduleBuffer(self.pcmBuffer, at: nil, options: (self.loop ? .loops : []), completionHandler: { [unowned self] in
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
        
        engine.detach(pcmPlayer)
        pcmPlayer = nil
        engine = nil
    }
}
