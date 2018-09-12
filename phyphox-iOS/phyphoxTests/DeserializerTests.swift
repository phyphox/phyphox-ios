//
//  DeserializerTests.swift
//  phyphoxTests
//
//  Created by Jonas Gessner on 15.06.18.
//  Copyright © 2018 Jonas Gessner. All rights reserved.
//

import Foundation
import XCTest
@testable import phyphox

/// Enum modeling deserialization results
private enum XMLParseResult {
    case failure
    case success
}

/// Returns the test bundle
var testBundle: Bundle {
    return Bundle(for: DeserializerTests.self)
}

/// Tests for the experiment deserializer. Tests that correct experiment files are deserialized properly and that incorrect files are properly detected as incorrect.
final class DeserializerTests: XCTestCase {
    private let experimentsBaseURL = testBundle.url(forResource: "phyphox-experiments", withExtension: nil)!

    /// Helper method that deserializes an experiment from an input stream using a `ResultElementHandler` and verifies that the result is the expected result (success or failure). In the case of success, the deserialized experiment is returned.
    @discardableResult private func expectParserResult<Handler: ResultElementHandler>(expectedResult: XMLParseResult, handler: Handler, inputStream: InputStream) throws -> Handler.Result? {
        let parser = DocumentParser(documentHandler: handler)

        switch expectedResult {
        case .failure:
            do {
               let result = try parser.parse(stream: inputStream)
                XCTFail()
                return result
            }
            catch {
                return nil
            }
        case .success:
            return try parser.parse(stream: inputStream)
        }
    }

    /// This test case deserializes all default experiment, ensuring that the deserializer successfully deserializes them without throwing an error.
    func testDefaultExperiments() throws {
        let experiments = try FileManager.default.contentsOfDirectory(atPath: experimentsBaseURL.path)

        let handler = PhyphoxDocumentHandler()

        for file in experiments {
            let url = experimentsBaseURL.appendingPathComponent(file)

            let stream = try InputStream(url: url).unwrap()

            try expectParserResult(expectedResult: .success, handler: handler, inputStream: stream)
        }
    }

    /// This test case deserializes an experiment from a file, which uses all features of experiments (sensor input, gps input, audio input, audio output, different view elements, export, different analysis modules). The experiment defined by the file is created hard-coded and the deserialized experiment is then compared to the hard-coded experiment for equality. This tests whether the deserializer properly deserializes the experiment.
    func testValueAccuracy() throws {
        let skeleton = try testBundle.path(forResource: "full-skeleton", ofType: "phyphox").unwrap()

        let handler = PhyphoxDocumentHandler()

        let fileExperiment = try expectParserResult(expectedResult: .success, handler: handler, inputStream: InputStream(fileAtPath: skeleton).unwrap())

        let links = [ExperimentLink(label: "l0", url: try URL(string: "http://test.test").unwrap(), highlighted: false)]

        let translation = ExperimentTranslationCollection(translations: ["de": ExperimentTranslation(withLocale: "de", strings: [:], titleString: "titlede", descriptionString: "descriptionde", categoryString: "categoryde", links: [:])], defaultLanguageCode: "en")

        let buffer = try DataBuffer(name: "buffer", storage: .memory(size: 1), baseContents: [0.0], static: false)

        let sensors = [ExperimentSensorInput(sensorType: .linearAcceleration, calibrated: false, motionSession: MotionSession.sharedSession(), rate: 0.0, average: false, xBuffer: buffer, yBuffer: buffer, zBuffer: buffer, tBuffer: buffer, absBuffer: buffer, accuracyBuffer: nil)]

        let gps = [ExperimentGPSInput(latBuffer: buffer, lonBuffer: buffer, zBuffer: buffer, vBuffer: buffer, dirBuffer: buffer, accuracyBuffer: buffer, zAccuracyBuffer: buffer, tBuffer: buffer, statusBuffer: buffer, satellitesBuffer: buffer)]

        let audioIn = [ExperimentAudioInput(sampleRate: 48000, outBuffer: buffer, sampleRateInfoBuffer: buffer)]

        let output = ExperimentOutput(audioOutput: ExperimentAudioOutput(sampleRate: 48000, loop: false, dataSource: buffer))

        let edit = EditViewDescriptor(label: "l1", translation: translation, signed: true, decimal: true, unit: "", factor: 1.0, min: -Double.infinity, max: Double.infinity, defaultValue: 0.0, buffer: buffer)

        let value = ValueViewDescriptor(label: "l2", translation: translation, size: 1.0, scientific: false, precision: 2, unit: "", factor: 1.0, buffer: buffer, mappings: [])

        let button = ButtonViewDescriptor(label: "l3", translation: translation, dataFlow: [(input: .value(value: 0.0, usedAs: ""), output: buffer)])

        let separator = SeparatorViewDescriptor(height: 1.0, color: kBackgroundColor)

        let info = InfoViewDescriptor(label: "l4", translation: translation)

        let graph = GraphViewDescriptor(label: "l6", translation: translation, xLabel: "l7", yLabel: "l8", xInputBuffer: buffer, yInputBuffer: buffer, logX: false, logY: false, xPrecision: 3, yPrecision: 3, scaleMinX: .auto, scaleMaxX: .auto, scaleMinY: .auto, scaleMaxY: .auto, minX: 0.0, maxX: 0.0, minY: 0.0, maxY: 0.0, aspectRatio: 3.0, drawDots: false, partialUpdate: false, history: 1, lineWidth: 1.0, color: kHighlightColor)

        let viewCollection = ExperimentViewCollectionDescriptor(label: "v1", translation: translation, views: [edit, value, button, separator, info, graph])

        let io = ExperimentAnalysisDataIO.buffer(buffer: buffer, usedAs: "", clear: true)

        let append = try AppendAnalysis(inputs: [io], outputs: [io], additionalAttributes: .empty)

        let add = try AdditionAnalysis(inputs: [io], outputs: [io], additionalAttributes: .empty)

        let subtract = try SubtractionAnalysis(inputs: [io], outputs: [io], additionalAttributes: .empty)

        let multiply = try MultiplicationAnalysis(inputs: [io], outputs: [io], additionalAttributes: .empty)

        let ifModule = try IfAnalysis(inputs: [.buffer(buffer: buffer, usedAs: "", clear: false), .value(value: 0.0, usedAs: ""), .buffer(buffer: buffer, usedAs: "", clear: false), .buffer(buffer: buffer, usedAs: "", clear: false)], outputs: [io], additionalAttributes: .empty)

        let analysis = ExperimentAnalysis(modules: [append, add, subtract, multiply, ifModule], sleep: 0.0, dynamicSleep: nil)

        let export = ExperimentExport(sets: [ExperimentExportSet(name: "n1", data: [(name: "n2", buffer: buffer)], translation: translation)])

        let experiment = Experiment(title: "title", description: "description", links: links, category: "category", icon: .string("icon"), persistentStorageURL: try URL(string: NSTemporaryDirectory()).unwrap(), translation: translation, buffers: ["buffer" : buffer], sensorInputs: sensors, gpsInputs: gps, audioInputs: audioIn, output: output, viewDescriptors: [viewCollection], analysis: analysis, export: export)

        XCTAssertEqual(fileExperiment, experiment)
    }

    /// This test case attempts to deserialize experiment files that are incorrectly formatted. This test ensures that PhyphoxDocumentHandler and child handlers properly handle incorrect files and throw an error when attempting to deserialize these incorrect files.
    func testIncorrectFiles() throws {
        let experimentsPath = try testBundle.path(forResource: "incorrect-files", ofType: nil).unwrap()
        let experiments = try FileManager.default.contentsOfDirectory(atPath: experimentsPath)

        let handler = PhyphoxDocumentHandler()

        for file in experiments {
            let url = experimentsBaseURL.appendingPathComponent(file)

            let stream = try InputStream(url: url).unwrap()

            try expectParserResult(expectedResult: .failure, handler: handler, inputStream: stream)
        }
    }
}
