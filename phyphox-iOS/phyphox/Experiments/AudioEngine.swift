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
private let audioOutputQueue = DispatchQueue(label: "de.rwth-aachen.phyphox.audioOutput", qos: .userInteractive, attributes: [])

final class AudioEngine {
    var stopExperimentDelegate: StopExperimentDelegate? = nil
    
    let bufferFrameCount: AVAudioFrameCount = 2048
    
    private var engine: AVAudioEngine? = nil
    private var playbackPlayer: AVAudioPlayerNode? = nil
    private var frameIndex: Int = 0
    private var endIndex: Int = 0
    private var recordInput: AVAudioInputNode? = nil
    
    private var playing = false
    
    private var playbackOut: ExperimentAudioOutput? = nil
    private var playbackStateToken = UUID()
    private var recordIn: ExperimentAudioInput? = nil
    
    private var format: AVAudioFormat? = nil
    
    private var sineLookup: [Float]?
    let sineLookupSize = 4096
    private var phases: [Double] = []
    
    private struct Beep {
        var phase: Double
        var duration: Int
        var f: Double
        var startFrame: Int
    }
    private var beep: Beep? = nil
    public var beepOnly = false
    
    enum AudioEngineError: Error {
        case RateMissmatch
        case NoInput
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
    
    @objc func audioInterrupted(_ notification: Notification) -> Void {
        guard let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
        }

        if type == .began {
            stopExperimentDelegate?.stopExperiment()
        }
    }
    
    func startEngine() throws {
        if playbackOut == nil && recordIn == nil {
            return
        }
        
        if playbackOut != nil {
            if sineLookup == nil {
                sineLookup = (0..<sineLookupSize).map{sin(2*Float.pi*Float($0)/Float(sineLookupSize))}
            }
        }
        
        let avSession = AVAudioSession.sharedInstance()
        if playbackOut != nil && recordIn != nil {
            try avSession.setCategory(AVAudioSession.Category.playAndRecord, options: AVAudioSession.CategoryOptions.defaultToSpeaker)
        } else if playbackOut != nil {
            try avSession.setCategory(AVAudioSession.Category.playback)
        } else if recordIn != nil {
            if !avSession.isInputAvailable {
                throw AudioEngineError.NoInput
            }
            try avSession.setCategory(AVAudioSession.Category.playAndRecord, options: AVAudioSession.CategoryOptions.defaultToSpeaker) //Just setting AVAudioSessionCategoryRecord interferes with VoiceOver as it silences every other audio output (as documented)
        }
        try avSession.setMode(AVAudioSession.Mode.measurement)
        if (avSession.isInputGainSettable) {
            try avSession.setInputGain(1.0)
        }
        
        let sampleRate =  playbackOut?.sampleRate ?? recordIn?.sampleRate ?? 0
        try avSession.setPreferredSampleRate(Double(sampleRate))
        
        try avSession.setActive(true)
        
        var audioDescription = monoFloatFormatWithSampleRate(Double(sampleRate))
        format = AVAudioFormat(streamDescription: &audioDescription)
        
        self.engine = AVAudioEngine()
        
        NotificationCenter.default.addObserver(self, selector: #selector(audioEngineConfigurationChange), name: NSNotification.Name.AVAudioEngineConfigurationChange, object: self.engine)
        NotificationCenter.default.addObserver(self, selector: #selector(audioInterrupted), name: AVAudioSession.interruptionNotification, object: avSession)
        
        if (playbackOut != nil) {
            self.playbackPlayer = AVAudioPlayerNode()
            self.engine!.attach(self.playbackPlayer!)
            self.engine!.connect(self.playbackPlayer!, to: self.engine!.mainMixerNode, format: self.format)
        }
        
        if (recordIn != nil) {
            self.recordInput = engine!.inputNode
            
            self.recordIn?.sampleRateInfoBuffer?.append(self.recordInput?.outputFormat(forBus: 0).sampleRate ?? avSession.sampleRate)
            
            self.recordInput!.installTap(onBus: 0, bufferSize: UInt32(avSession.sampleRate/10), format: self.recordInput?.outputFormat(forBus: 0), block: {(buffer, time) in
                audioInputQueue.async {
                    autoreleasepool {
                        let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
                        let data = UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength))
                        
                        self.recordIn?.sampleRateInfoBuffer?.append(self.recordInput?.outputFormat(forBus: 0).sampleRate ?? avSession.sampleRate)
                        self.recordIn?.outBuffer.appendFromArray(data.map { Double($0) })
                    }
                }
            })
            
        }
        
        try self.engine!.start()
    }
    
    func play() {
        guard let playbackOut = playbackOut else {
            return
        }
        guard let format = format else {
            return
        }
        
        if !playing {
            playing = true
            frameIndex = 0
            endIndex = 0
            phases = [Double](repeating: 0.0, count: playbackOut.tones.count)
            
            if let inBuffer = playbackOut.directSource {
                endIndex = max(endIndex, inBuffer.count);
            }
            for tone in playbackOut.tones {
                endIndex = max(endIndex, Int((tone.duration.getValue() ?? 0.0) * format.sampleRate))
            }
            if let noise = playbackOut.noise {
                endIndex = max(endIndex, Int((noise.duration.getValue() ?? 0.0) * format.sampleRate))
            }
            
            appendBufferToPlayback()
            appendBufferToPlayback()
            appendBufferToPlayback()
            appendBufferToPlayback()
            
            self.playbackPlayer!.play()
        }
    }
    
    func appendBufferToPlayback() {
        guard let playbackOut = playbackOut else {
            return
        }
        guard let format = format else {
            return
        }
        
        var data = [Float](repeating: 0, count: Int(bufferFrameCount))
        
        var totalAmplitude: Float = 0.0

        //Beeper
        var beeping = false
        beeper: if let beeper = beep {
            let amplitude: Float = 0.5
            guard let sineLookup = sineLookup else {
                break beeper
            }
            totalAmplitude += amplitude
            if beeper.startFrame < 0 {
                beep!.startFrame = frameIndex
            }
            let end = min(Int(bufferFrameCount), beep!.startFrame + beeper.duration - frameIndex)
            if end <= 0 {
                beep = nil
                break beeper
            }
            beeping = true
            let phaseStep = beeper.f / (Double)(format.sampleRate)
            for i in 0..<end {
                let lookupIndex = Int(beep!.phase*Double(sineLookupSize)) % sineLookupSize
                data[i] += amplitude*sineLookup[lookupIndex]
                beep!.phase += phaseStep
            }
            if frameIndex > beep!.startFrame + beeper.duration {
                beep = nil
            }
        }
        
        if !beepOnly {
            addDirectBuffer: if let inBuffer = playbackOut.directSource {
                let inArray = inBuffer.toArray()
                let sampleCount = inArray.count
                guard sampleCount > 0 else {
                    break addDirectBuffer
                }
                let start = playbackOut.loop ? frameIndex % sampleCount : frameIndex
                let end = min(inArray.count, start+Int(bufferFrameCount))
                if end > start {
                    data.replaceSubrange(0..<end-start, with: inArray[start..<end].map { Float($0) })
                }
                if playbackOut.loop {
                    var offset = end-start
                    while offset < Int(bufferFrameCount) {
                        let subEnd = min(inArray.count, Int(bufferFrameCount)-offset)
                        data.replaceSubrange(offset..<offset+subEnd, with: inArray[0..<subEnd].map { Float($0) })
                        offset += subEnd
                    }
                }
                totalAmplitude += 1.0
            }

            for (i, tone) in playbackOut.tones.enumerated() {
                guard let f = tone.frequency.getValue(), f > 0 else {
                    continue
                }
                guard let a = tone.amplitude.getValue(), a > 0 else {
                    continue
                }
                totalAmplitude += Float(a)
                guard let d = tone.duration.getValue(), d > 0 else {
                    continue
                }
                guard let sineLookup = sineLookup else {
                    continue
                }
                let end: Int
                if playbackOut.loop {
                    end = Int(bufferFrameCount)
                } else {
                    end = min(Int(bufferFrameCount), Int(d * format.sampleRate)-frameIndex)
                }
                if end < 1 {
                    continue
                }
                //Phase is not tracked at a periodicity of 0..2pi but 0..1 as it is converted to the range of the lookuptable anyways
                let phaseStep = f / (Double)(format.sampleRate)
                var phase = phases[i]
                for i in 0..<end {
                    let lookupIndex = Int(phase*Double(sineLookupSize)) % sineLookupSize
                    data[i] += Float(a)*sineLookup[lookupIndex]
                    phase += phaseStep
                }
                while phase > 100000 {
                    phase -= 100000
                }
                phases[i] = phase
            }

            addNoise: if let noise = playbackOut.noise {
                guard let a = noise.amplitude.getValue(), a > 0 else {
                    break addNoise
                }
                totalAmplitude += Float(a)
                guard let d = noise.duration.getValue(), d > 0 else {
                    break addNoise
                }
                let end: Int
                if playbackOut.loop {
                    end = Int(bufferFrameCount)
                } else {
                    end = min(Int(bufferFrameCount), Int(d * format.sampleRate)-frameIndex)
                }
                if end < 1 {
                    break addNoise
                }
                for i in 0..<end {
                    data[i] += Float.random(in: -Float(a)...Float(a))
                }
            }
        }

        guard totalAmplitude > 0 else {
            stop()
            return
        }
        
        if playbackOut.normalize {
            for i in 0..<Int(bufferFrameCount) {
                data[i] = data[i] / totalAmplitude
            }
        }
        
        frameIndex += Int(bufferFrameCount)
            
        guard let buffer = AVAudioPCMBuffer(pcmFormat: self.format!, frameCapacity: bufferFrameCount) else {
            stop()
            return
        }
        buffer.floatChannelData?[0].assign(from: &data, count: Int(bufferFrameCount))
        buffer.frameLength = UInt32(bufferFrameCount)
        
        if !playing {
            return
        }
        self.playbackPlayer!.scheduleBuffer(buffer, at: nil, options: [], completionHandler: { [unowned self] in
            if self.playing && (self.playbackOut?.loop ?? false || self.frameIndex < self.endIndex || beeping) {
                audioOutputQueue.async {
                    self.appendBufferToPlayback()
                }
            } else {
                self.playing = false
            }
        })
    }
    
    func stop() {
        if playing {
            playing = false
            self.playbackPlayer!.stop()
        }
    }
    
    func stopEngine() {
        if let beeper = beep, let sampleRate = format?.sampleRate, playing {
            let maxRemainingSamples: Int
            if beeper.startFrame >= 0 {
                maxRemainingSamples = beeper.startFrame + beeper.duration - frameIndex + 4*Int(bufferFrameCount)
            } else {
                maxRemainingSamples = beeper.duration
            }
            let timeUntilBeeperEnds = TimeInterval(Double(maxRemainingSamples)/sampleRate)
            Thread.sleep(forTimeInterval: timeUntilBeeperEnds)
        }
        stop()
        
        engine?.stop()
        engine = nil
        
        playbackPlayer = nil
        
        playbackOut = nil
        recordIn = nil
        
        let avSession = AVAudioSession.sharedInstance()
        do {
            try avSession.setActive(false)
        } catch {
            
        }
    }
    
    func beep(frequency: Double, duration: Double) {
        guard let sampleRate = format?.sampleRate else {
            print("No format specified. Can't beep.")
            return
        }
        beep = Beep(phase: 0.0, duration: Int(duration * sampleRate), f: frequency, startFrame: -1)
        self.play()
    }
    
}
