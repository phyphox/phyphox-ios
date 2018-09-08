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
            throw ElementHandlerError.missingAttribute("output")
        }

        let sampleRateBuffer = descriptor.buffer(for: "rate", from: buffers)

        self.init(sampleRate: descriptor.rate, outBuffer: outBuffer, sampleRateInfoBuffer: sampleRateBuffer)
    }
}

struct SemanticVersion: Comparable {
    let major: UInt
    let minor: UInt
    let patch: UInt

    init(major: UInt, minor: UInt, patch: UInt) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init?(string: String) {
        let components = string.components(separatedBy: ".")

        guard components.count >= 2 else { return nil }

        guard let major = UInt(components[0]) else { return nil }
        guard let minor = UInt(components[1]) else { return nil }

        self.major = major
        self.minor = minor

        if components.count >= 3 {
            guard let patch = UInt(components[2]) else { return nil }

            self.patch = patch
        }
        else {
            self.patch = 0
        }
    }

    static func <(lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        guard lhs.major <= rhs.major else { return false }
        guard lhs.major == rhs.major else { return true }

        guard lhs.minor <= rhs.minor else { return false }
        guard lhs.minor == rhs.minor else { return true }

        guard lhs.patch <= rhs.patch else { return false }
        guard lhs.patch == rhs.patch else { return true }

        return false
    }
}

private let latestSupportedFileVersion = SemanticVersion(major: 1, minor: 6, patch: 0)

final class PhyphoxElementHandler: ResultElementHandler, LookupElementHandler {
    var results = [Experiment]()

    var childHandlers: [String: ElementHandler]

    private let titleHandler = TextElementHandler()
    private let categoryHandler = TextElementHandler()
    private let descriptionHandler = MultilineTextElementHandler()
    private let iconHandler = IconElementHandler()
    private let linkHandler = LinkElementHandler()
    private let dataContainersHandler = DataContainersElementHandler()
    private let translationsHandler = TranslationsElementHandler()
    private let inputHandler = InputElementHandler()
    private let outputHandler = OutputElementHandler()
    private let analysisHandler = AnalysisElementHandler()
    private let viewsHandler = ViewsElementHandler()
    private let exportHandler = ExportElementHandler()

    init() {
        childHandlers = ["title": titleHandler, "category": categoryHandler, "description": descriptionHandler, "icon": iconHandler, "link": linkHandler, "data-containers": dataContainersHandler, "translations": translationsHandler, "input": inputHandler, "output": outputHandler, "analysis": analysisHandler, "views": viewsHandler, "export": exportHandler]
    }

    private enum Attribute: String, ClosedAttributeKey {
        case locale
        case version
    }

    func startElement(attributes: AttributeContainer) throws {}

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)
        
        let locale = attributes.optionalString(for: .locale) ?? "en"

        let versionString = try attributes.string(for: .version)

        guard let version = SemanticVersion(string: versionString) else {
            throw ElementHandlerError.unexpectedAttributeValue("version")
        }

        guard version <= latestSupportedFileVersion else {
            throw ElementHandlerError.message("File version \(versionString) is not supported")
        }

        let translations = try translationsHandler.expectOptionalResult().map { ExperimentTranslationCollection(translations: $0, defaultLanguageCode: locale) }

        guard let title = try titleHandler.expectOptionalResult() ?? translations?.selectedTranslation?.titleString else {
            throw ElementHandlerError.missingElement("title")
        }

        guard let category = try categoryHandler.expectOptionalResult() ?? translations?.selectedTranslation?.categoryString else {
            throw ElementHandlerError.missingElement("category")
        }

        guard let description = try descriptionHandler.expectOptionalResult() ?? translations?.selectedTranslation?.descriptionString else {
            throw ElementHandlerError.missingElement("description")
        }

        let icon = try iconHandler.expectOptionalResult() ?? .string(String(title[..<min(title.index(title.startIndex, offsetBy: 2), title.endIndex)]).uppercased())

        let links = linkHandler.results

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

        let output = try outputDescriptor.map { try makeOutput(from: $0, buffers: buffers) }

        let sensorInputs = inputDescriptor?.sensors.map { ExperimentSensorInput(descriptor: $0, buffers: buffers) } ?? []
        let gpsInputs = inputDescriptor?.location.map { ExperimentGPSInput(descriptor: $0, buffers: buffers) } ?? []
        let audioInputs = try inputDescriptor?.audio.map { try ExperimentAudioInput(descriptor: $0, buffers: buffers) } ?? []

        let exportDescriptor = try exportHandler.expectSingleResult()
        let export = try makeExport(from: exportDescriptor, buffers: buffers, translations: translations)

        let viewCollectionDescriptors = try viewsHandler.expectOptionalResult()

        let viewDescriptors = try viewCollectionDescriptors?.map { ExperimentViewCollectionDescriptor(label: $0.label, translation: translations, views: try $0.views.map { try makeViewDescriptor(from: $0, buffers: buffers, translations: translations) })  }

        let experiment = Experiment(title: title, description: description, links: links, category: category, icon: icon, persistentStorageURL: experimentPersistentStorageURL, translation: translations, buffers: buffers, sensorInputs: sensorInputs, gpsInputs: gpsInputs, audioInputs: audioInputs, output: output, viewDescriptors: viewDescriptors, analysis: analysis, export: export)

        results.append(experiment)
    }

    private func makeViewDescriptor(from descriptor: ViewElementDescriptor, buffers: [String: DataBuffer], translations: ExperimentTranslationCollection?) throws -> ViewDescriptor {
        if let descriptor = descriptor as? SeparatorViewElementDescriptor {
            return SeparatorViewDescriptor(height: descriptor.height, color: descriptor.color)
        }
        else if let descriptor = descriptor as? InfoViewElementDescriptor {
            return InfoViewDescriptor(label: descriptor.label, translation: translations)
        }
        else if let descriptor = descriptor as? ValueViewElementDescriptor {
            guard let buffer = buffers[descriptor.inputBufferName] else {
                throw ElementHandlerError.missingElement("data-container")
            }

            return ValueViewDescriptor(label: descriptor.label, translation: translations, size: descriptor.size, scientific: descriptor.scientific, precision: descriptor.precision, unit: descriptor.unit, factor: descriptor.factor, buffer: buffer, mappings: descriptor.mappings)
        }
        else if let descriptor = descriptor as? EditViewElementDescriptor {
            guard let buffer = buffers[descriptor.outputBufferName] else {
                throw ElementHandlerError.missingElement("data-container")
            }

            if buffer.isEmpty {
                buffer.append(descriptor.defaultValue)
            }

            return EditViewDescriptor(label: descriptor.label, translation: translations, signed: descriptor.signed, decimal: descriptor.decimal, unit: descriptor.unit, factor: descriptor.factor, min: descriptor.min, max: descriptor.max, defaultValue: descriptor.defaultValue, buffer: buffer)
        }
        else if let descriptor = descriptor as? ButtonViewElementDescriptor {
            let dataFlow = try descriptor.dataFlow.map { flow -> (ExperimentAnalysisDataIO, DataBuffer) in
                guard let outputBuffer = buffers[flow.outputBufferName] else {
                    throw ElementHandlerError.missingElement("data-container")
                }

                let input: ExperimentAnalysisDataIO

                switch flow.input {
                case .buffer(let bufferName):
                    guard let buffer = buffers[bufferName] else {
                        throw ElementHandlerError.missingElement("data-container")
                    }

                    input = .buffer(buffer: buffer, usedAs: "", clear: true)
                case .value(let value):
                    input = .value(value: value, usedAs: "")
                case .clear:
                    input = .buffer(buffer: emptyBuffer, usedAs: "", clear: true)
                }

                return (input, outputBuffer)
            }

            return ButtonViewDescriptor(label: descriptor.label, translation: translations, dataFlow: dataFlow)
        }
        else if let descriptor = descriptor as? GraphViewElementDescriptor {
            let xBuffer = try descriptor.xInputBufferName.map({ name -> DataBuffer in
                guard let buffer = buffers[name] else {
                    throw ElementHandlerError.missingElement("data-container")
                }
                return buffer
            })

            guard let yBuffer = buffers[descriptor.yInputBufferName] else {
                throw ElementHandlerError.missingElement("data-container")
            }

            return GraphViewDescriptor(label: descriptor.label, translation: translations, xLabel: descriptor.xLabel, yLabel: descriptor.yLabel, xInputBuffer: xBuffer, yInputBuffer: yBuffer, logX: descriptor.logX, logY: descriptor.logY, xPrecision: descriptor.xPrecision, yPrecision: descriptor.yPrecision, scaleMinX: descriptor.scaleMinX, scaleMaxX: descriptor.scaleMaxX, scaleMinY: descriptor.scaleMinY, scaleMaxY: descriptor.scaleMaxY, minX: descriptor.minX, maxX: descriptor.maxX, minY: descriptor.minY, maxY: descriptor.maxY, aspectRatio: descriptor.aspectRatio, drawDots: descriptor.drawDots, partialUpdate: descriptor.partialUpdate, history: descriptor.history, lineWidth: descriptor.lineWidth, color: descriptor.color)
        }
        else {
            throw ElementHandlerError.message("Unknown View Descriptor: \(descriptor)")
        }
    }

    private func makeOutput(from descriptor: OutputDescriptor, buffers: [String: DataBuffer]) throws -> ExperimentOutput {
        let audioOutput = descriptor.audioOutput

        return ExperimentOutput(audioOutput: try audioOutput.map {
            guard let buffer = buffers[$0.inputBufferName] else {
                throw ElementHandlerError.missingElement("data-container")
            }

            return ExperimentAudioOutput(sampleRate: $0.rate, loop: $0.loop, dataSource: buffer)
        })
    }

    private func makeExport(from descriptors: [ExportSetDescriptor], buffers: [String: DataBuffer], translations: ExperimentTranslationCollection?) throws -> ExperimentExport {
        let sets = try descriptors.map { descriptor -> ExperimentExportSet in
            let dataSets = try descriptor.dataSets.map { set -> (String, DataBuffer) in
                guard let buffer = buffers[set.bufferName] else {
                    throw ElementHandlerError.missingElement("data-container")
                }

                return (descriptor.name, buffer)
            }

            return ExperimentExportSet(name: descriptor.name, data: dataSets, translation: translations)
        }

        return ExperimentExport(sets: sets)
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
            case .empty:
                return nil
            }
        })

        return Set(inputBufferNames)
    }
}
