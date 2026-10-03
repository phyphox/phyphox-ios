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
    private var recordInput: AVAudioInputNode? = nil
    
    var playing = false //internal for the retrigger tests, which have no engine
    
    private var playbackOut: ExperimentAudioOutput? = nil
    private var playbackStateToken = UUID()
    private var recordIn: ExperimentAudioInput? = nil
    
    private var format: AVAudioFormat? = nil
    
    let sineLookupSize = 4096
    private lazy var sineLookup: [Float] = (0..<sineLookupSize).map{sin(2*Float.pi*Float($0)/Float(sineLookupSize))}
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
        self.phases = [Double](repeating: 0.0, count: audioOutput?.tones.count ?? 0)
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
        
        let avSession = AVAudioSession.sharedInstance()
        //mixWithOthers: a tone generator works while music plays, as Android's AudioTrack never takes audio focus
        //allowBluetoothA2DP: output stays on Bluetooth headphones while recording, as on Android (not allowBluetooth: HFP would take over the mic at 8/16 kHz)
        if playbackOut != nil && recordIn != nil {
            try avSession.setCategory(AVAudioSession.Category.playAndRecord, options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers])
        } else if playbackOut != nil {
            try avSession.setCategory(AVAudioSession.Category.playback, options: [.mixWithOthers])
        } else if recordIn != nil {
            if !avSession.isInputAvailable {
                throw AudioEngineError.NoInput
            }
            try avSession.setCategory(AVAudioSession.Category.playAndRecord, options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers]) //Just setting AVAudioSessionCategoryRecord interferes with VoiceOver as it silences every other audio output (as documented)
        }
        try avSession.setMode(AVAudioSession.Mode.measurement)
        if (avSession.isInputGainSettable) {
            try avSession.setInputGain(1.0)
        }
        
        let sampleRate =  playbackOut?.sampleRate ?? recordIn?.sampleRate ?? 0
        try avSession.setPreferredSampleRate(Double(sampleRate))
        
        try avSession.setActive(true)
        
        //Stereo since the pan parameter (file format 1.20), as on Android
        format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 2)
        
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
            
            //The block must not touch the input node: it runs after stopEngine has released the engine that owns it (the most frequent crash in the field). The buffer carries the format.
            self.recordInput!.installTap(onBus: 0, bufferSize: UInt32(avSession.sampleRate/10), format: self.recordInput?.outputFormat(forBus: 0), block: { [weak self] (buffer, time) in
                audioInputQueue.async {
                    autoreleasepool {
                        guard let self = self, let recordIn = self.recordIn else {
                            return
                        }
                        let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
                        let data = UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength))
                        
                        recordIn.sampleRateInfoBuffer?.append(buffer.format.sampleRate)
                        recordIn.backBuffer.appendFromArray(data.map { Double($0) })
                    }
                }
            })
            
        }
        
        try self.engine!.start()
    }
    
    //As on Android: non-finite values (including doubles beyond float range) become zero
    private func sanitizedParameter(_ value: Double?) -> Double {
        guard let value = value else {
            return 0.0
        }
        let f = Float(value)
        return f.isFinite ? Double(f) : 0.0
    }

    //Like a Java (int) cast: NaN becomes 0, out-of-range values saturate
    private func javaInt(_ value: Double) -> Int {
        if value.isNaN {
            return 0
        }
        if value >= Double(Int32.max) {
            return Int(Int32.max)
        }
        if value <= Double(Int32.min) {
            return Int(Int32.min)
        }
        return Int(value)
    }

    //The trigger at the end of every analysis cycle. A one-shot output starts over from its beginning, a looped output
    //that is already playing continues undisturbed (phyphox-docs spec/output.yml, attribute loop). Both pick up new data
    //with the next generated block.
    func play() {
        guard let playbackOut = playbackOut else {
            return
        }
        if playing {
            if !playbackOut.loop {
                //The completion handlers advance frameIndex on this queue. The blocks already queued play first, so the
                //restart is heard with the next generated block, as on Android.
                audioOutputQueue.sync {
                    self.restart()
                }
            }
            return
        }
        startPlayback()
    }

    //A beep shifts with the restart, as on Android, so a running timed-run beep is not stretched. The tone phases are
    //kept to avoid a click; only the durations count from zero again.
    private func restart() {
        if let beeper = beep, beeper.startFrame >= 0 {
            beep!.startFrame -= frameIndex
        }
        frameIndex = 0
    }

    private func startPlayback() {
        guard let playbackOut = playbackOut, format != nil, !playing else {
            return
        }
        playing = true
        frameIndex = 0
        phases = [Double](repeating: 0.0, count: playbackOut.tones.count)
        
        appendBufferToPlayback()
        appendBufferToPlayback()
        appendBufferToPlayback()
        appendBufferToPlayback()
        
        self.playbackPlayer!.play()
    }

    //The frame at which the one-shot sources end, read from the data and parameters current now rather than from when
    //playback started: a direct source that has grown plays on, one that has shrunk stops earlier (as on Android).
    func currentEndIndex() -> Int {
        guard let playbackOut = playbackOut else {
            return 0
        }
        let sampleRate = Double(playbackOut.sampleRate)
        var endIndex = 0
        if let inBuffer = playbackOut.directSource {
            endIndex = max(endIndex, inBuffer.count)
        }
        for tone in playbackOut.tones {
            endIndex = max(endIndex, javaInt(sanitizedParameter(tone.duration.getValue()) * sampleRate))
        }
        if let noise = playbackOut.noise {
            endIndex = max(endIndex, javaInt(sanitizedParameter(noise.duration.getValue()) * sampleRate))
        }
        return endIndex
    }

    //Whether another block has to be generated after the current one
    func playbackContinues(beeping: Bool) -> Bool {
        guard playing, let playbackOut = playbackOut else {
            return false
        }
        return playbackOut.loop || beeping || frameIndex < currentEndIndex()
    }

    func appendBufferToPlayback() {
        guard let block = nextBlock() else {
            stop()
            return
        }
        var dataLeft = block.left
        var dataRight = block.right
        let beeping = block.beeping

        guard let format = format, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferFrameCount) else {
            stop()
            return
        }
        buffer.floatChannelData?[0].update(from: &dataLeft, count: Int(bufferFrameCount))
        buffer.floatChannelData?[1].update(from: &dataRight, count: Int(bufferFrameCount))
        buffer.frameLength = UInt32(bufferFrameCount)
        
        if !playing {
            return
        }
        self.playbackPlayer!.scheduleBuffer(buffer, at: nil, options: [], completionHandler: { [unowned self] in
            if self.playbackContinues(beeping: beeping) {
                audioOutputQueue.async {
                    self.appendBufferToPlayback()
                }
            } else {
                self.playing = false
            }
        })
    }

    //Generates the next block of bufferFrameCount stereo frames and advances frameIndex. Returns nil when nothing is
    //left to play. Split from the scheduling so the retrigger behaviour can be tested without an audio engine.
    func nextBlock() -> (left: [Float], right: [Float], beeping: Bool)? {
        guard let playbackOut = playbackOut else {
            return nil
        }
        let sampleRate = Double(playbackOut.sampleRate)
        
        var dataLeft = [Float](repeating: 0, count: Int(bufferFrameCount))
        var dataRight = [Float](repeating: 0, count: Int(bufferFrameCount))

        var totalAmplitude: Float = 0.0

        //As on Android: centred plays at full amplitude on both channels, panning attenuates the opposite one
        func panFactors(_ parameter: AudioParameter) -> (left: Float, right: Float) {
            var p = Float(parameter.getValue() ?? 0.0)
            if !p.isFinite {
                p = 0.0
            }
            return (left: p > 0 ? 1.0 - p : 1.0, right: p < 0 ? 1.0 + p : 1.0)
        }

        //Beeper
        var beeping = false
        beeper: if let beeper = beep {
            let amplitude: Float = 0.5
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
            let phaseStep = beeper.f / sampleRate
            for i in 0..<end {
                let lookupIndex = Int(beep!.phase*Double(sineLookupSize)) % sineLookupSize
                let v = amplitude*sineLookup[lookupIndex]
                dataLeft[i] += v
                dataRight[i] += v
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
                    for i in 0..<end-start {
                        let v = Float(inArray[start+i])
                        dataLeft[i] += v
                        dataRight[i] += v
                    }
                }
                if playbackOut.loop {
                    var offset = end-start
                    while offset < Int(bufferFrameCount) {
                        let subEnd = min(inArray.count, Int(bufferFrameCount)-offset)
                        for i in 0..<subEnd {
                            let v = Float(inArray[i])
                            dataLeft[offset+i] += v
                            dataRight[offset+i] += v
                        }
                        offset += subEnd
                    }
                }
                totalAmplitude += 1.0
            }

            for (i, tone) in playbackOut.tones.enumerated() {
                let f = sanitizedParameter(tone.frequency.getValue())
                guard f > 0 else {
                    continue
                }
                let a = sanitizedParameter(tone.amplitude.getValue())
                guard a > 0 else {
                    continue
                }
                totalAmplitude += Float(a)
                let d = sanitizedParameter(tone.duration.getValue())
                guard d > 0 else {
                    continue
                }
                let end: Int
                if playbackOut.loop {
                    end = Int(bufferFrameCount)
                } else {
                    end = min(Int(bufferFrameCount), javaInt(d * sampleRate)-frameIndex)
                }
                if end < 1 {
                    continue
                }
                let (panLeft, panRight) = panFactors(tone.pan)
                //Phase is not tracked at a periodicity of 0..2pi but 0..1 as it is converted to the range of the lookuptable anyways
                let phaseStep = f / sampleRate
                var phase = phases[i]
                switch tone.waveform {
                case .sine:
                    for i in 0..<end {
                        let lookupIndex = javaInt(phase*Double(sineLookupSize)) % sineLookupSize
                        let v = Float(a)*sineLookup[lookupIndex]
                        dataLeft[i] += panLeft * v
                        dataRight[i] += panRight * v
                        phase += phaseStep
                    }
                case .square:
                    for i in 0..<end {
                        let lookupIndex = javaInt(phase*Double(sineLookupSize)) % sineLookupSize
                        let v = (2*lookupIndex > sineLookupSize ? Float(a) : -Float(a))
                        dataLeft[i] += panLeft * v
                        dataRight[i] += panRight * v
                        phase += phaseStep
                    }
                case .sawtooth:
                    for i in 0..<end {
                        let lookupIndex = javaInt(phase*Double(sineLookupSize)) % sineLookupSize
                        let v = Float(a) * (2 * Float(lookupIndex) / Float(sineLookupSize) - 1.0)
                        dataLeft[i] += panLeft * v
                        dataRight[i] += panRight * v
                        phase += phaseStep
                    }
                }

                phases[i] = phase
            }

            addNoise: if let noise = playbackOut.noise {
                let a = sanitizedParameter(noise.amplitude.getValue())
                guard a > 0 else {
                    break addNoise
                }
                totalAmplitude += Float(a)
                let d = sanitizedParameter(noise.duration.getValue())
                guard d > 0 else {
                    break addNoise
                }
                let end: Int
                if playbackOut.loop {
                    end = Int(bufferFrameCount)
                } else {
                    end = min(Int(bufferFrameCount), javaInt(d * sampleRate)-frameIndex)
                }
                if end < 1 {
                    break addNoise
                }
                let (panLeft, panRight) = panFactors(noise.pan)
                //Like on Android, both channels receive the same random value
                for i in 0..<end {
                    let v = Float.random(in: -Float(a)...Float(a))
                    dataLeft[i] += panLeft * v
                    dataRight[i] += panRight * v
                }
            }
        }

        guard totalAmplitude > 0 else {
            return nil
        }

        if playbackOut.normalize {
            for i in 0..<Int(bufferFrameCount) {
                dataLeft[i] = dataLeft[i] / totalAmplitude
                dataRight[i] = dataRight[i] / totalAmplitude
            }
        }

        frameIndex += Int(bufferFrameCount)

        return (left: dataLeft, right: dataRight, beeping: beeping)
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
        
        NotificationCenter.default.removeObserver(self)
        recordInput?.removeTap(onBus: 0)
        recordInput = nil
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
        startPlayback() //a beep joins a playing output without restarting it, the output is only retriggered by the analysis
    }
    
}
