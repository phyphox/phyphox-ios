//
//  AudioEngine.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 30.04.17.
//  Copyright © 2017 RWTH Aachen. All rights reserved.
//

import Foundation
import AVFoundation

final class AudioEngine {
    
    private var engine: AVAudioEngine? = nil
    private var playbackPlayer: AVAudioPlayerNode? = nil
    private var playbackBuffer: AVAudioPCMBuffer? = nil
    private var recordInputNode: AVAudioInputNode? = nil
    
    private var playing = false
    
    private var playbackOut: ExperimentAudioOutput? = nil
    private var playbackStateToken: UUID?
    
    private var recordDataBuffer: DataBuffer? = nil
    
    private var format: AVAudioFormat? = nil
    
    enum AudioEngineError: Error {
        case RateMissmatch
    }
    
    init() {
        
    }
    
    @objc func audioEngineConfigurationChange(_ notification: Notification) -> Void {
        let wasPlaying = playing
        
        stop()
        
        if (wasPlaying) {
            play()
        }
    }
    
    func startEngine(playback: ExperimentAudioOutput?, recordInput: ExperimentAudioInput?) throws {
        if playback == nil && recordInput == nil {
            return
        }
        
        playbackOut = playback
        
        let avSession = AVAudioSession.sharedInstance()
        if playback != nil && recordInput != nil {
            try avSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: AVAudioSessionCategoryOptions.defaultToSpeaker)
        } else if playback != nil {
            try avSession.setCategory(AVAudioSessionCategoryPlayback)
        } else if recordInput != nil {
            try avSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: AVAudioSessionCategoryOptions.defaultToSpeaker) //Just setting AVAudioSessionCategoryRecord interferes with VoiceOver as it silences every other audio output (as documented)
        }
        try avSession.setMode(AVAudioSessionModeMeasurement)
        if (avSession.isInputGainSettable) {
            try avSession.setInputGain(1.0)
        }
        
        let sampleRate = recordInput?.sampleRate ?? playbackOut?.sampleRate ?? 0
        try avSession.setPreferredSampleRate(Double(sampleRate))
        
        try avSession.setActive(true)
        
        var audioDescription = monoFloatFormatWithSampleRate(avSession.sampleRate)
        format = AVAudioFormat(streamDescription: &audioDescription)

        let engine = AVAudioEngine()

        self.engine = engine
        
        NotificationCenter.default.addObserver(self, selector: #selector(audioEngineConfigurationChange), name: NSNotification.Name.AVAudioEngineConfigurationChange, object: self.engine)
        
        if playback != nil {
            let playbackPlayer = AVAudioPlayerNode()
            self.playbackPlayer = playbackPlayer

            engine.attach(playbackPlayer)
            engine.connect(playbackPlayer, to: engine.mainMixerNode, format: format)
        }
        
        if let recordInput = recordInput {
            let recordInputNode = engine.inputNode
            self.recordInputNode = recordInputNode

            recordDataBuffer = recordInput.outBuffer
            
            recordInputNode.installTap(onBus: 0, bufferSize: UInt32(avSession.sampleRate/10), format: format!, block: {(buffer, time) in
                audioInputQueue.async (execute: {
                    autoreleasepool(invoking: {
                        let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
                        let data = UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength))
                        recordInput.sampleRateInfoBuffer?.append(AVAudioSession.sharedInstance().sampleRate)
                        self.recordDataBuffer?.appendFromArray(Array(data).flatMap{ Double($0 )})
                    })
                })
            })
            
        }
        
        try engine.start()
    }
    
    func play() {
        if playbackOut == nil {
            return
        }
        
        if !playing || !self.playbackOut!.dataSource.stateTokenIsValid(self.playbackStateToken) {
            playing = true
            
            //If a buffer gets played and paused repeatedly (like the sonar) but the content that is played is always the same the buffer doesn't need to be created again.
            if self.playbackBuffer == nil || !self.playbackOut!.dataSource.stateTokenIsValid(self.playbackStateToken) {
                var source = self.playbackOut!.dataSource.toArray().map { Float($0) }
                self.playbackStateToken = self.playbackOut!.dataSource.getStateToken() as UUID?
                
                if self.playbackPlayer!.isPlaying {
                    self.playbackBuffer = nil
                    self.playbackPlayer!.stop()
                }
                
                if source.count == 0 {
                    //There is no data to play
                    playing = false
                    return
                }
                
                self.playbackBuffer = AVAudioPCMBuffer(pcmFormat: self.format!, frameCapacity: UInt32(source.count))
                self.playbackBuffer!.floatChannelData?[0].assign(from: &source, count: source.count)
                self.playbackBuffer!.frameLength = UInt32(source.count)
            }
            
            do {
                weak var bufferRef = self.playbackBuffer
                self.playbackPlayer!.play()
                self.playbackPlayer!.scheduleBuffer(self.playbackBuffer!, at: nil, options: (playbackOut!.loop ? .loops : []), completionHandler: { [unowned self] in
                    if bufferRef == self.playbackBuffer { //bufferRef != self.pcmBuffer <=> pcmBuffer was cancelled and recreated because the data source changed, playback should not be cancelled.
                        self.playing = false
                    }
                })
            }
        }
    }

    func stop() {
        if playing {
            self.playbackPlayer!.stop()
            playing = false
        }
    }
    
    func stopEngine() {
        stop()
        
        engine?.stop()
        engine = nil
        
        playbackPlayer = nil
        playbackBuffer = nil
        
        playbackOut = nil
        
        recordDataBuffer = nil
        
        let avSession = AVAudioSession.sharedInstance()
        do {
            try avSession.setActive(false)
        } catch {
            
        }
    }
    
}
