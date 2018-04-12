//
//  PhyphoxElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

private extension SensorDescriptor {
    func buffer(for component: String, from buffers: [String: DataBuffer]) -> DataBuffer? {
        return (outputs.first(where: { $0.component == component })?.bufferName).map { buffers[$0] } ?? nil
    }
}

private extension ExperimentSensorInput {
    convenience init(descriptor: SensorInputDescriptor, buffers: [String: DataBuffer]) {
        let xBuffer = descriptor.buffer(for: "x", from: buffers)
        let yBuffer = descriptor.buffer(for: "y", from: buffers)
        let zBuffer = descriptor.buffer(for: "z", from: buffers)
        let tBuffer = descriptor.buffer(for: "t", from: buffers)
        let absBuffer = descriptor.buffer(for: "abs", from: buffers)
        let accuracyBuffer = descriptor.buffer(for: "accuracy", from: buffers)

        self.init(sensorType: descriptor.sensor, calibrated: true, motionSession: MotionSession.sharedSession(), rate: descriptor.rate, average: descriptor.average, xBuffer: xBuffer, yBuffer: yBuffer, zBuffer: zBuffer, tBuffer: tBuffer, absBuffer: absBuffer, accuracyBuffer: accuracyBuffer)
    }
}

private extension ExperimentGPSInput {
    convenience init(descriptor: LocationInputDescriptor, buffers: [String: DataBuffer]) {
        let latBuffer = descriptor.buffer(for: "lat", from: buffers)
        let lonBuffer = descriptor.buffer(for: "lon", from: buffers)
        let zBuffer = descriptor.buffer(for: "z", from: buffers)
        let vBuffer = descriptor.buffer(for: "v", from: buffers)
        let dirBuffer = descriptor.buffer(for: "dir", from: buffers)
        let accuracyBuffer = descriptor.buffer(for: "accuracy", from: buffers)
        let zAccuracyBuffer = descriptor.buffer(for: "zAccuracy", from: buffers)
        let tBuffer = descriptor.buffer(for: "t", from: buffers)
        let statusBuffer = descriptor.buffer(for: "status", from: buffers)
        let satellitesBuffer = descriptor.buffer(for: "satellites", from: buffers)

        self.init(latBuffer: latBuffer, lonBuffer: lonBuffer, zBuffer: zBuffer, vBuffer: vBuffer, dirBuffer: dirBuffer, accuracyBuffer: accuracyBuffer, zAccuracyBuffer: zAccuracyBuffer, tBuffer: tBuffer, statusBuffer: statusBuffer, satellitesBuffer: satellitesBuffer)
    }
}

private extension ExperimentAudioInput {
    convenience init(descriptor: AudioInputDescriptor, buffers: [String: DataBuffer]) throws {
        guard let outBuffer = descriptor.buffer(for: "output", from: buffers) else {
            throw ParseError.missingAttribute("output")
        }

        let sampleRateBuffer = descriptor.buffer(for: "rate", from: buffers)

        self.init(sampleRate: descriptor.rate, outBuffer: outBuffer, sampleRateInfoBuffer: sampleRateBuffer)
    }
}

final class PhyphoxElementHandler: ResultElementHandler, LookupElementHandler {
    typealias Result = Experiment
    
    var results = [Result]()

    var handlers: [String: ElementHandler]

    private let titleHandler = TextElementHandler()
    private let categoryHandler = TextElementHandler()
    private let descriptionHandler = TextElementHandler()
    private let iconHandler = IconHandler()
    private let linkHandler = LinkHandler()
    private let dataContainersHandler = DataContainersHandler()
    private let translationsHandler = TranslationsHandler()
    private let inputHandler = InputHandler()
    private let outputHandler = OutputHandler()
    private let analysisHandler = AnalysisHandler()

    init() {
        handlers = ["title": titleHandler, "category": categoryHandler, "description": descriptionHandler, "icon": iconHandler, "link": linkHandler, "data-containers": dataContainersHandler, "translations": translationsHandler, "input": inputHandler, "outputHandler": outputHandler, "analysis": analysisHandler]
    }

    func beginElement(attributes: [String : String]) throws {
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        let locale = attributes["locale"] ?? "en"
        guard let version = attributes["version"] else {
            throw ParseError.missingAttribute("version")
        }

        let title = try titleHandler.expectSingleResult()
        let category = try categoryHandler.expectSingleResult()
        let description = try descriptionHandler.expectSingleResult()
        let icon = try iconHandler.expectOptionalResult() ?? ExperimentIcon(string: title, image: nil)
        let translations = try translationsHandler.expectOptionalResult()

        let dataContainersDescriptor = try dataContainersHandler.expectSingleResult()
        let analysisDescriptor = try analysisHandler.expectOptionalResult()

        let analysisInputBufferNames = analysisDescriptor.map { getInputBufferNames(from: $0) } ?? []

        let experimentPersistentStorageURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)

        let buffers = try makeBuffers(from: dataContainersDescriptor, analysisInputBufferNames: analysisInputBufferNames, experimentPersistentStorageURL: experimentPersistentStorageURL)

        let analysis = try analysisDescriptor.map { descriptor -> ExperimentAnalysis in
            let analysisModules = try descriptor.modules.map({ try ExperimentAnalysisFactory.analysisModule(from: $1, for: $0, buffers: buffers) })

            return ExperimentAnalysis(modules: analysisModules, sleep: descriptor.sleep, dynamicSleep: descriptor.dynamicSleepName.map { buffers[$0] } ?? nil)
        }

        let inputDescriptor = try inputHandler.expectOptionalResult()
        let outputDescriptor = try outputHandler.expectOptionalResult()

        let sensorInputs = inputDescriptor?.sensors.map { ExperimentSensorInput(descriptor: $0, buffers: buffers) }
        let gpsInputs = inputDescriptor?.location.map { ExperimentGPSInput(descriptor: $0, buffers: buffers) }
        let audioInputs = try inputDescriptor?.audio.map { try ExperimentAudioInput(descriptor: $0, buffers: buffers) }

        
    }

    private func makeBuffers(from descriptors: [BufferDescriptor], analysisInputBufferNames: Set<String>, experimentPersistentStorageURL: URL) throws -> [String: DataBuffer] {
        var buffers: [String: DataBuffer] = [:]

        for descriptor in descriptors {
            let storageType: DataBuffer.StorageType

            let bufferSize = descriptor.size
            let name = descriptor.name
            let staticBuffer = descriptor.staticBuffer
            let baseContents = descriptor.baseContents

            if bufferSize == 0 && !analysisInputBufferNames.contains(name) {
                let bufferURL = experimentPersistentStorageURL.appendingPathComponent(name).appendingPathExtension(bufferContentsFileExtension)

                storageType = .hybrid(memorySize: 5000, persistentStorageLocation: bufferURL)
            }
            else {
                storageType = .memory(size: bufferSize)
            }

            let buffer = try DataBuffer(name: name, storage: storageType, baseContents: baseContents, static: staticBuffer)

            buffers[name] = buffer

        }

        return buffers
    }

    private func getInputBufferNames(from analysis: AnalysisDescriptor) -> Set<String> {
        let inputBufferNames = analysis.modules.flatMap({ $0.descriptor.inputs }).compactMap({ descriptor -> String? in
            switch descriptor {
            case .buffer(name: let name, usedAs: _, clear: _):
                return name
            case .value(value: _, usedAs: _):
                return nil
            }
        })

        return Set(inputBufferNames)
    }
}
