//
//  AudioOutputRetriggerTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

//Playback is triggered after every analysis cycle. A trigger starts a one-shot output over from its beginning, while a
//looped output that is already playing continues undisturbed (phyphox-docs spec/output.yml). Blocks are generated with
//nextBlock() directly, without an audio engine. Mirrors Android's AudioOutputRetriggerTest.
final class AudioOutputRetriggerTests: XCTestCase {

    private let block = 2048

    //A waveform whose samples are all different, so the position within it can be read back
    private func sample(_ i: Int, _ length: Int) -> Float {
        return Float(0.9 * (2.0 * Double(i) / Double(length) - 1.0))
    }

    private func waveform(_ length: Int) throws -> DataBuffer {
        let buffer = try DataBuffer(name: "waveform", size: length, baseContents: [], static: false)
        for i in 0..<length {
            buffer.append(Double(sample(i, length)))
        }
        return buffer
    }

    //Marks the output as playing without an engine
    private func playingEngine(loop: Bool, directSource: DataBuffer?, tones: [ExperimentAudioOutputTone] = []) -> AudioEngine {
        let output = ExperimentAudioOutput(sampleRate: 48000, loop: loop, normalize: false, directSource: directSource, tones: tones, noise: nil)
        let engine = AudioEngine(audioOutput: output, audioInput: nil)
        engine.playing = true
        return engine
    }

    private func assertBlock(_ data: (left: [Float], right: [Float], beeping: Bool)?, startsAt position: Int, length: Int, samples: Int = 2048, _ message: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let data = try XCTUnwrap(data, "a block must be generated", file: file, line: line)
        for i in stride(from: 0, to: samples, by: 97) {
            let expected = sample((position + i) % length, length)
            XCTAssertEqual(data.left[i], expected, accuracy: 1e-6, "\(message) (sample \(i))", file: file, line: line)
            XCTAssertEqual(data.right[i], expected, accuracy: 1e-6, "\(message) (right channel, sample \(i))", file: file, line: line)
        }
    }

    func testALoopedOutputIsNotRestartedWhilePlaying() throws {
        let length = 3000 //does not divide the block size, so a restart would be a jump
        let engine = playingEngine(loop: true, directSource: try waveform(length))

        _ = engine.nextBlock()
        _ = engine.nextBlock()
        engine.play()
        try assertBlock(engine.nextBlock(), startsAt: 2*block, length: length, "a looped output must continue where it was after a trigger")
    }

    func testAOneShotOutputStartsOverOnATrigger() throws {
        let length = 10000
        let engine = playingEngine(loop: false, directSource: try waveform(length))

        _ = engine.nextBlock()
        _ = engine.nextBlock()
        engine.play()
        try assertBlock(engine.nextBlock(), startsAt: 0, length: length, "a one-shot output must start over from its first sample after a trigger")
    }

    func testAOneShotToneStartsOverOnATrigger() throws {
        let tone = ExperimentAudioOutputTone(waveform: .square, frequency: .value(value: 1000), amplitude: .value(value: 1.0), duration: .value(value: 0.01), pan: .value(value: 0)) //480 samples, less than a block
        let engine = playingEngine(loop: false, directSource: nil, tones: [tone])

        XCTAssertNotEqual(try XCTUnwrap(engine.nextBlock()).left[10], 0, "the tone must sound in the first block")
        XCTAssertEqual(try XCTUnwrap(engine.nextBlock()).left[10], 0, "the tone must have ended after its duration")
        engine.play()
        XCTAssertNotEqual(try XCTUnwrap(engine.nextBlock()).left[10], 0, "a trigger must start the tone's duration over")
    }

    //The end of a one-shot output follows the data that is current, not the data from when playback started
    func testAOneShotOutputEndsWithTheCurrentData() throws {
        let length = 3000
        let source = try DataBuffer(name: "source", size: 2*length, baseContents: [], static: false)
        for i in 0..<length {
            source.append(Double(sample(i, length)))
        }
        let engine = playingEngine(loop: false, directSource: source)

        _ = engine.nextBlock()
        XCTAssertTrue(engine.playbackContinues(beeping: false), "the source extends into the second block")
        _ = engine.nextBlock()
        XCTAssertFalse(engine.playbackContinues(beeping: false), "the source is exhausted after two blocks")

        //The next analysis cycle doubles the source: it is not cut at the end seen when playback started
        for i in 0..<length {
            source.append(Double(sample(i, length)))
        }
        XCTAssertTrue(engine.playbackContinues(beeping: false), "a source that has grown plays on past its old end")
        try assertBlock(engine.nextBlock(), startsAt: 2*block, length: length, samples: 2*length - 2*block, "the third block reads the appended samples")
    }
}
