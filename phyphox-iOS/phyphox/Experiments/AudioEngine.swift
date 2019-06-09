//
//  AudioEngine.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 30.04.17.
//  Copyright © 2017 RWTH Aachen. All rights reserved.
//

import Foundation
import AVFoundation

private let audioInputQueue = DispatchQueue(label: "de.rwth-aachen.phyphox.audioInput", attributes: [])

final class AudioEngine {
    
    private var engine: AVAudioEngine? = nil
    private var playbackPlayer: AVAudioPlayerNode? = nil
    private var playbackBuffer: AVAudioPCMBuffer? = nil
    private var recordInput: AVAudioInputNode? = nil
    
    private var playing = false
    
    private var playbackOut: ExperimentAudioOutput? = nil
    private var playbackStateToken = UUID()
    private var recordIn: ExperimentAudioInput? = nil
    
    private var format: AVAudioFormat? = nil
    
    private var audioOutput: ExperimentAudioOutput? = nil
    private var audioInput: ExperimentAudioInput? = nil
    
    enum AudioEngineError: Error {
        case RateMissmatch
    }
    
    init(audioOutput: ExperimentAudioOutput?, audioInput: ExperimentAudioInput?) {
        self.playbackOut = audioOutput
        self.recordIn = audioInput
    }
    
    @objc func audioEngineConfigurationChange(_ notification: Notification) -> Void {
        let wasPlaying = playing
        
        stop()
        
        if (wasPlaying) {
            play()
        }
    }
    
    func startEngine() throws {
        if playbackOut == nil && recordIn == nil {
            return
        }
        
        let avSession = AVAudioSession.sharedInstance()
        if playbackOut != nil && recordIn != nil {
            try avSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: AVAudioSessionCategoryOptions.defaultToSpeaker)
        } else if playbackOut != nil {
            try avSession.setCategory(AVAudioSessionCategoryPlayback)
        } else if recordIn != nil {
            try avSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: AVAudioSessionCategoryOptions.defaultToSpeaker) //Just setting AVAudioSessionCategoryRecord interferes with VoiceOver as it silences every other audio output (as documented)
        }
        try avSession.setMode(AVAudioSessionModeMeasurement)
        if (avSession.isInputGainSettable) {
            try avSession.setInputGain(1.0)
        }
        
        let sampleRate = recordIn?.sampleRate ?? playbackOut?.sampleRate ?? 0
        try avSession.setPreferredSampleRate(Double(sampleRate))
        
        try avSession.setActive(true)
        
        var audioDescription = monoFloatFormatWithSampleRate(avSession.sampleRate)
        format = AVAudioFormat(streamDescription: &audioDescription)
        
        self.engine = AVAudioEngine()
        
        NotificationCenter.default.addObserver(self, selector: #selector(audioEngineConfigurationChange), name: NSNotification.Name.AVAudioEngineConfigurationChange, object: self.engine)
        
        if (playbackOut != nil) {
            self.playbackPlayer = AVAudioPlayerNode()
            self.engine!.attach(self.playbackPlayer!)
            self.engine!.connect(self.playbackPlayer!, to: self.engine!.mainMixerNode, format: self.format)
        }
        
        if (recordIn != nil) {
            self.recordInput = engine!.inputNode
            
            self.recordInput!.installTap(onBus: 0, bufferSize: UInt32(avSession.sampleRate/10), format: format!, block: {(buffer, time) in
                audioInputQueue.async {
                    autoreleasepool {
                        let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
                        let data = UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength))
                        
                        self.recordIn?.sampleRateInfoBuffer?.append(AVAudioSession.sharedInstance().sampleRate)
                        self.recordIn?.outBuffer.appendFromArray(data.map { Double($0) })
                    }
                }
            })
            
        }
        
        try self.engine!.start()
    }
    
    func play() {
        if playbackOut == nil {
            return
        }
        
        if !playing ||  !self.playbackOut!.dataSource.stateTokenIsValid(self.playbackStateToken) {
            playing = true
            
            //If a buffer gets played and paused repeatedly (like the sonar) but the content that is played is always the same the buffer doesn't need to be created again.
            if self.playbackBuffer == nil || !self.playbackOut!.dataSource.stateTokenIsValid(self.playbackStateToken) {
                var source = self.playbackOut!.dataSource.toArray().map { Float($0) }
                self.playbackStateToken = self.playbackOut!.dataSource.stateToken
                
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
        recordIn = nil
        
        let avSession = AVAudioSession.sharedInstance()
        do {
            try avSession.setActive(false)
        } catch {
            
        }
    }
    
}
