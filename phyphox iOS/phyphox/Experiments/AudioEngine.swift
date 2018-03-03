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
    private let engine = AVAudioEngine()
    private let format: AVAudioFormat

    private var playbackPlayer: AVAudioPlayerNode?
    private var playbackBuffer: AVAudioPCMBuffer?

    private var playing = false

    private var audioOutput: ExperimentAudioOutput? = nil
    private var playbackStateToken: UUID?

    init(audioOutput: ExperimentAudioOutput?, audioInput: ExperimentAudioInput?) throws {
        self.audioOutput = audioOutput

        let avSession = AVAudioSession.sharedInstance()

        if audioOutput != nil && audioInput != nil {
            try avSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: AVAudioSessionCategoryOptions.defaultToSpeaker)
        }
        else if audioOutput != nil {
            try avSession.setCategory(AVAudioSessionCategoryPlayback)
        }
        else if audioInput != nil {
            try avSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: AVAudioSessionCategoryOptions.defaultToSpeaker) //Just setting AVAudioSessionCategoryRecord interferes with VoiceOver as it silences every other audio output (as documented)
        }

        try avSession.setMode(AVAudioSessionModeMeasurement)

        if avSession.isInputGainSettable {
            try avSession.setInputGain(1.0)
        }

        if let sampleRate = audioInput?.sampleRate ?? audioOutput?.sampleRate {
            try avSession.setPreferredSampleRate(Double(sampleRate))
        }

        var audioDescription = monoFloatFormatWithSampleRate(avSession.sampleRate)
        format = AVAudioFormat(streamDescription: &audioDescription)!

        NotificationCenter.default.addObserver(self, selector: #selector(audioEngineConfigurationChange), name: NSNotification.Name.AVAudioEngineConfigurationChange, object: self.engine)

        if audioOutput != nil {
            let playbackPlayer = AVAudioPlayerNode()
            self.playbackPlayer = playbackPlayer

            engine.attach(playbackPlayer)
            engine.connect(playbackPlayer, to: engine.mainMixerNode, format: format)
        }

        if let audioInput = audioInput {
            let recordInputNode = engine.inputNode

            recordInputNode.installTap(onBus: 0, bufferSize: UInt32(avSession.sampleRate/10), format: format, block: {(buffer, time) in
                audioInputQueue.async (execute: {
                    autoreleasepool(invoking: {
                        let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
                        let data = UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength))

                        audioInput.sampleRateInfoBuffer?.append(AVAudioSession.sharedInstance().sampleRate)
                        audioInput.outBuffer.appendFromArray(Array(data).flatMap{ Double($0 )})
                    })
                })
            })
        }
    }

    enum AudioEngineError: Error {
        case RateMissmatch
    }
    
    @objc private func audioEngineConfigurationChange(_ notification: Notification) -> Void {
        let wasPlaying = playing
        
        stopAudioOutput()
        
        if wasPlaying {
            playAudioOutput()
        }
    }
    
    func startEngine() throws {
        try AVAudioSession.sharedInstance().setActive(true)
        try engine.start()
        playAudioOutput()
    }
    
    func playAudioOutput() {
        guard let audioOutput = audioOutput, let playbackPlayer = playbackPlayer else { return }
        
        if !playing || !audioOutput.dataSource.stateTokenIsValid(playbackStateToken) {
            playing = true

            //If a buffer gets played and paused repeatedly (like the sonar) but the content that is played is always the same the buffer doesn't need to be created again.
            if playbackBuffer == nil || !audioOutput.dataSource.stateTokenIsValid(playbackStateToken) {
                var source = audioOutput.dataSource.toArray().map { Float($0) }
                playbackStateToken = audioOutput.dataSource.getStateToken()
                
                if playbackPlayer.isPlaying {
                    playbackBuffer = nil
                    playbackPlayer.stop()
                }
                
                if source.isEmpty {
                    //There is no data to play
                    playing = false
                    return
                }

                playbackBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(source.count))
                playbackBuffer?.floatChannelData?[0].assign(from: &source, count: source.count)
                playbackBuffer?.frameLength = UInt32(source.count)
            }

            guard let playbackBuffer = playbackBuffer else { return }

            weak var bufferRef = playbackBuffer
            playbackPlayer.play()
            playbackPlayer.scheduleBuffer(playbackBuffer, at: nil, options: (audioOutput.loop ? .loops : []), completionHandler: { [unowned self] in
                if bufferRef == self.playbackBuffer { //bufferRef != self.pcmBuffer <=> pcmBuffer was cancelled and recreated because the data source changed, playback should not be cancelled.
                    self.playing = false
                }
            })
        }
    }

    private func stopAudioOutput() {
        if playing {
            playbackPlayer?.stop()
            playbackBuffer = nil
            playing = false
        }
    }
    
    func stopEngine() throws {
        stopAudioOutput()
        engine.stop()
        try AVAudioSession.sharedInstance().setActive(false)
    }
}
