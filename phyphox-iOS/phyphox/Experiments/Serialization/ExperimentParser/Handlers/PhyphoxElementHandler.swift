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
    private let descriptionHandler = MultilineTextHandler()
    private let iconHandler = IconHandler()
    private let linkHandler = LinkHandler()
    private let dataContainersHandler = DataContainersHandler()
    private let translationsHandler = TranslationsHandler()
    private let inputHandler = InputHandler()
    private let outputHandler = OutputHandler()
    private let analysisHandler = AnalysisHandler()
    private let viewsHandler = ViewsHandler()
    private let exportHandler = ExportHandler()

    init() {
        handlers = ["title": titleHandler, "category": categoryHandler, "description": descriptionHandler, "icon": iconHandler, "link": linkHandler, "data-containers": dataContainersHandler, "translations": translationsHandler, "input": inputHandler, "output": outputHandler, "analysis": analysisHandler, "views": viewsHandler, "export": exportHandler]
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

        let output = try makeOutput(from: outputDescriptor, buffers: buffers)

        let sensorInputs = inputDescriptor?.sensors.map { ExperimentSensorInput(descriptor: $0, buffers: buffers) } ?? []
        let gpsInputs = inputDescriptor?.location.map { ExperimentGPSInput(descriptor: $0, buffers: buffers) } ?? []
        let audioInputs = try inputDescriptor?.audio.map { try ExperimentAudioInput(descriptor: $0, buffers: buffers) } ?? []

        let exportDescriptor = try exportHandler.expectSingleResult()
        let export = try makeExport(from: exportDescriptor, buffers: buffers, translations: translations)

        let viewCollectionDescriptors = try viewsHandler.expectOptionalResult()

        let viewDescriptors = try viewCollectionDescriptors?.map { ExperimentViewCollectionDescriptor(label: $0.label, translation: translations, views: try $0.views.map { try makeViewDescriptor(from: $0, buffers: buffers, translations: translations) })  }

        let experiment = Experiment(title: title, description: description, links: links, category: category, icon: icon, local: true, persistentStorageURL: experimentPersistentStorageURL, translation: translations, buffers: buffers, sensorInputs: sensorInputs, gpsInputs: gpsInputs, audioInputs: audioInputs, output: output, viewDescriptors: viewDescriptors, analysis: analysis, export: export)

        results.append(experiment)
    }

    private func makeViewDescriptor(from descriptor: ViewElementDescriptor, buffers: [String: DataBuffer], translations: ExperimentTranslationCollection?) throws -> ViewDescriptor {
        if let descriptor = descriptor as? SeparatorViewElementDescriptor {
            let color = try descriptor.color.map({ string -> UIColor in
                guard let color = UIColor(hexString: string) else {
                    throw ParseError.unreadableData
                }

                return color
            }) ?? kBackgroundColor

            return SeparatorViewDescriptor(height: descriptor.height, color: color)
        }
        else if let descriptor = descriptor as? InfoViewElementDescriptor {
            return InfoViewDescriptor(label: descriptor.label, translation: translations)
        }
        else if let descriptor = descriptor as? ValueViewElementDescriptor {
            guard let buffer = buffers[descriptor.inputBufferName] else {
                throw ParseError.missingElement
            }

            return ValueViewDescriptor(label: descriptor.label, translation: translations, size: descriptor.size, scientific: descriptor.scientific, precision: descriptor.precision, unit: descriptor.unit, factor: descriptor.factor, buffer: buffer, mappings: descriptor.mappings)
        }
        else if let descriptor = descriptor as? EditViewElementDescriptor {
            guard let buffer = buffers[descriptor.outputBufferName] else {
                throw ParseError.missingElement
            }

            if buffer.isEmpty {
                buffer.append(descriptor.defaultValue)
            }

            return EditViewDescriptor(label: descriptor.label, translation: translations, signed: descriptor.signed, decimal: descriptor.decimal, unit: descriptor.unit, factor: descriptor.factor, min: descriptor.min, max: descriptor.max, defaultValue: descriptor.defaultValue, buffer: buffer)
        }
        else if let descriptor = descriptor as? ButtonViewElementDescriptor {
            let dataFlow = try descriptor.dataFlow.map { flow -> (ExperimentAnalysisDataIO, DataBuffer) in
                guard let outputBuffer = buffers[flow.outputBufferName] else {
                    throw ParseError.missingElement
                }

                let input: ExperimentAnalysisDataIO

                switch flow.input {
                case .buffer(let bufferName):
                    guard let buffer = buffers[bufferName] else {
                        throw ParseError.missingElement
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
                    throw ParseError.missingElement
                }
                return buffer
            })

            guard let yBuffer = buffers[descriptor.yInputBufferName] else {
                throw ParseError.missingElement
            }

            let color = try descriptor.color.map({ string -> UIColor in
                guard let color = UIColor(hexString: string) else {
                    throw ParseError.unreadableData
                }

                return color
            }) ?? kHighlightColor

            return GraphViewDescriptor(label: descriptor.label, translation: translations, xLabel: descriptor.xLabel, yLabel: descriptor.yLabel, xInputBuffer: xBuffer, yInputBuffer: yBuffer, logX: descriptor.logX, logY: descriptor.logY, xPrecision: descriptor.xPrecision, yPrecision: descriptor.yPrecision, scaleMinX: descriptor.scaleMinX, scaleMaxX: descriptor.scaleMaxX, scaleMinY: descriptor.scaleMinY, scaleMaxY: descriptor.scaleMaxY, minX: descriptor.minX, maxX: descriptor.maxX, minY: descriptor.minY, maxY: descriptor.maxY, aspectRatio: descriptor.aspectRatio, drawDots: descriptor.drawDots, partialUpdate: descriptor.partialUpdate, history: descriptor.history, lineWidth: descriptor.lineWidth, color: color)
        }
        else {
            throw ParseError.unexpectedElement
        }
    }

    private func makeOutput(from descriptor: AudioOutputDescriptor?, buffers: [String: DataBuffer]) throws -> ExperimentOutput? {
        guard let descriptor = descriptor else {
            return nil
        }

        guard let buffer = buffers[descriptor.inputBufferName] else {
            throw ParseError.missingElement
        }

        return ExperimentOutput(audioOutput: ExperimentAudioOutput(sampleRate: descriptor.rate, loop: descriptor.loop, dataSource: buffer))
    }

    private func makeExport(from descriptors: [ExportSetDescriptor], buffers: [String: DataBuffer], translations: ExperimentTranslationCollection?) throws -> ExperimentExport {
        let sets = try descriptors.map { descriptor -> ExperimentExportSet in
            let dataSets = try descriptor.dataSets.map { set -> (String, DataBuffer) in
                guard let buffer = buffers[set.bufferName] else {
                    throw ParseError.missingElement
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

infix operator =-=: ComparisonPrecedence

protocol DebugComparison {
    static func =-= (lhs: Self, rhs: Self) -> Bool
}

extension Dictionary: DebugComparison where Value: DebugComparison {
    static func =-= (lhs: Dictionary<Key, Value>, rhs: Dictionary<Key, Value>) -> Bool {
        for (key, value) in lhs {
            guard let other = rhs[key], value =-= other else { return false }
        }

        return true
    }
}

extension Array: DebugComparison where Element: DebugComparison {
    static func =-= (lhs: Array, rhs: Array) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return !zip(lhs, rhs).contains(where: { !($0 =-= $1) })
    }
}

extension Optional: DebugComparison where Wrapped: DebugComparison {
    static func =-= (lhs: Optional<Wrapped>, rhs: Optional<Wrapped>) -> Bool {
        if let left = lhs {
            if let right = rhs {
                return left =-= right
            }
            else {
                return false
            }
        }
        else {
            return rhs == nil
        }
    }
}

extension ExperimentIcon: DebugComparison {
    static func =-=(lhs: ExperimentIcon, rhs: ExperimentIcon) -> Bool {
        return lhs.string == rhs.string &&
            lhs.image.map({ UIImagePNGRepresentation($0) }) == rhs.image.map({ UIImagePNGRepresentation($0) })
    }
}

extension ExperimentTranslation: DebugComparison {
    static func =-=(lhs: ExperimentTranslation, rhs: ExperimentTranslation) -> Bool {
        return lhs.locale == rhs.locale &&
        lhs.titleString == rhs.titleString &&
        lhs.descriptionString == rhs.descriptionString &&
        lhs.categoryString == rhs.categoryString &&
        lhs.translatedLinks == rhs.translatedLinks &&
        lhs.translatedStrings == rhs.translatedStrings
    }
}

extension ExperimentTranslationCollection: DebugComparison {
    static func =-=(lhs: ExperimentTranslationCollection, rhs: ExperimentTranslationCollection) -> Bool {
        return lhs.translations =-= rhs.translations &&
            lhs.selectedTranslation =-= rhs.selectedTranslation
    }
}

extension DataBuffer.StorageType: DebugComparison {
    static func =-=(lhs: DataBuffer.StorageType, rhs: DataBuffer.StorageType) -> Bool {
        switch lhs {
        case .memory(size: let l):
            switch rhs {
            case .memory(size: let r):
                return l == r
            default:
                return false
            }
        case .hybrid(memorySize: let l, persistentStorageLocation: _):
            switch rhs {
            case .hybrid(memorySize: let r, persistentStorageLocation: _):
                return l == r
            default:
                return false
            }
        }
    }
}

extension DataBuffer: DebugComparison {
    static func =-=(lhs: DataBuffer, rhs: DataBuffer) -> Bool {
        return lhs.storageType =-= rhs.storageType &&
        lhs.toArray() == rhs.toArray()
    }
}

extension ExperimentSensorInput: DebugComparison {
    static func =-= (lhs: ExperimentSensorInput, rhs: ExperimentSensorInput) -> Bool {
        return lhs.sensorType == rhs.sensorType &&
            lhs.rate == rhs.rate &&
            lhs.recordingAverages == rhs.recordingAverages &&
            lhs.xBuffer =-= rhs.xBuffer &&
            lhs.yBuffer =-= rhs.yBuffer &&
            lhs.zBuffer =-= rhs.zBuffer &&
            lhs.tBuffer =-= rhs.tBuffer &&
            lhs.absBuffer =-= rhs.absBuffer &&
            lhs.accuracyBuffer =-= rhs.accuracyBuffer &&
            lhs.calibrated == rhs.calibrated
    }
}

extension ExperimentGPSInput: DebugComparison {
    static func =-= (lhs: ExperimentGPSInput, rhs: ExperimentGPSInput) -> Bool {
        return lhs.latBuffer =-= rhs.latBuffer &&
            lhs.lonBuffer =-= rhs.lonBuffer &&
            lhs.zBuffer =-= rhs.zBuffer &&
            lhs.vBuffer =-= rhs.vBuffer &&
            lhs.dirBuffer =-= rhs.dirBuffer &&
            lhs.accuracyBuffer =-= rhs.accuracyBuffer &&
            lhs.zAccuracyBuffer =-= rhs.zAccuracyBuffer &&
            lhs.tBuffer =-= rhs.tBuffer &&
            lhs.statusBuffer =-= rhs.statusBuffer &&
            lhs.satellitesBuffer =-= rhs.satellitesBuffer
    }
}

extension ExperimentAudioInput: DebugComparison {
    static func =-=(lhs: ExperimentAudioInput, rhs: ExperimentAudioInput) -> Bool {
        return lhs.sampleRate == rhs.sampleRate &&
            lhs.outBuffer =-= rhs.outBuffer &&
            lhs.sampleRateInfoBuffer =-= rhs.sampleRateInfoBuffer
    }
}

extension ExperimentAudioOutput: DebugComparison {
    static func =-=(lhs: ExperimentAudioOutput, rhs: ExperimentAudioOutput) -> Bool {
        return lhs.sampleRate == rhs.sampleRate &&
            lhs.loop == rhs.loop &&
            lhs.dataSource =-= rhs.dataSource
    }
}

extension ExperimentOutput: DebugComparison {
    static func =-=(lhs: ExperimentOutput, rhs: ExperimentOutput) -> Bool {
        return lhs.audioOutput =-= rhs.audioOutput
    }
}

extension ExperimentAnalysisDataIO: DebugComparison {
    static func =-=(lhs: ExperimentAnalysisDataIO, rhs: ExperimentAnalysisDataIO) -> Bool {
        switch lhs {
        case .buffer(buffer: let la, usedAs: let lb, clear: let lc):
            switch rhs {
            case .buffer(buffer: let ra, usedAs: let rb, clear: let rc):
                return la =-= ra &&
                    lb == rb &&
                    lc == rc
            default:
                return false
            }
        case .value(value: let la, usedAs: let lb):
            switch rhs {
            case .value(value: let ra, usedAs: let rb):
                return la == ra &&
                    lb == rb
            default:
                return false
            }
        }
    }
}

extension Collection where Element: DebugComparison {
    func contentsEqual<Other: RangeReplaceableCollection>(_ other: Other) -> Bool where Other.Element == Element  {
        guard count == other.count else { return false }

        var lookup = other

        for element in self {
            guard let index = lookup.index(where: { element =-= $0 }) else {
                return false
            }
            lookup.remove(at: index)
        }

        return true
    }
}

extension ExperimentAnalysisModule: DebugComparison {
    static func =-=(lhs: ExperimentAnalysisModule, rhs: ExperimentAnalysisModule) -> Bool {
        return lhs.attributes == rhs.attributes &&
        lhs.inputs.contentsEqual(rhs.inputs) &&
        lhs.outputs.contentsEqual(rhs.outputs)
    }
}

extension ExperimentAnalysis: DebugComparison {
    static func =-=(lhs: ExperimentAnalysis, rhs: ExperimentAnalysis) -> Bool {
        return lhs.sleep == rhs.sleep &&
        lhs.dynamicSleep =-= rhs.dynamicSleep &&
        lhs.modules =-= rhs.modules
    }
}

extension ExperimentLink: DebugComparison {
    static func =-=(lhs: ExperimentLink, rhs: ExperimentLink) -> Bool {
        return lhs.label == rhs.label &&
            lhs.url == rhs.url &&
            lhs.highlighted == rhs.highlighted
    }
}

extension Experiment: DebugComparison {
    static func =-=(lhs: Experiment, rhs: Experiment) -> Bool {
        print(lhs.title == rhs.title)
        print(lhs.localizedDescription == rhs.localizedDescription)
        print(lhs.localizedLinks =-= rhs.localizedLinks)
        print(lhs.localizedCategory == rhs.localizedCategory)
        print(lhs.icon =-= rhs.icon)
        print(lhs.local == rhs.local)
        print(lhs.translation =-= rhs.translation)
        print(lhs.buffers =-= rhs.buffers)
        print(lhs.sensorInputs =-= rhs.sensorInputs)
        print(lhs.gpsInputs =-= rhs.gpsInputs)
        print(lhs.audioInputs =-= rhs.audioInputs)
        print(lhs.output =-= rhs.output)
        print(lhs.analysis =-= rhs.analysis)
        
        return lhs.title == rhs.title &&
            lhs.localizedDescription == rhs.localizedDescription &&
            lhs.localizedLinks =-= rhs.localizedLinks &&
            lhs.localizedCategory == rhs.localizedCategory &&
            lhs.icon =-= rhs.icon &&
            lhs.local == rhs.local &&
            lhs.translation =-= rhs.translation &&
            lhs.buffers =-= rhs.buffers &&
            lhs.sensorInputs =-= rhs.sensorInputs &&
            lhs.gpsInputs =-= rhs.gpsInputs &&
            lhs.audioInputs =-= rhs.audioInputs &&
            lhs.output =-= rhs.output &&
            //lhs.viewDescriptors == rhs.viewDescriptors &&
            lhs.analysis =-= rhs.analysis //&&
            //lhs.export == rhs.export
    }
}
