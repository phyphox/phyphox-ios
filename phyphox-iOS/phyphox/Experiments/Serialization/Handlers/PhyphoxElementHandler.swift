//
//  PhyphoxElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreBluetooth

// MARK: - Extensions required for the initialization of an Experiment instance.
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
    init(descriptor: AudioInputDescriptor, buffers: [String: DataBuffer]) throws {
        guard let outBuffer = descriptor.buffer(for: "output", from: buffers) else {
            throw ElementHandlerError.missingAttribute("output")
        }

        let sampleRateBuffer = descriptor.buffer(for: "rate", from: buffers)

        self.init(sampleRate: descriptor.rate, outBuffer: outBuffer, sampleRateInfoBuffer: sampleRateBuffer)
    }
}

private extension ExperimentBluetoothInput {
    convenience init(device: ExperimentBluetoothDevice, descriptor: BluetoothInputBlockDescriptor, buffers: [String: DataBuffer]) throws {
        
        var outputs: [BluetoothOutput] = []
        for output in descriptor.outputs {
            guard let outBuffer = buffers[output.bufferName] else {
                throw ElementHandlerError.message("No such buffer: \(output.bufferName)")
            }
            outputs.append(BluetoothOutput(char: output.char, conversion: output.conversion, buffer: outBuffer, extra: output.extra))
        }
        
        self.init(device: device, mode: descriptor.mode, outputList: outputs, configList: descriptor.configs, subscribeOnStart: descriptor.subscribeOnStart, rate: descriptor.rate)
    }
}

private extension ExperimentBluetoothOutput {
    convenience init(device: ExperimentBluetoothDevice, descriptor: BluetoothOutputBlockDescriptor, buffers: [String: DataBuffer]) throws {
        
        var inputs: [BluetoothInput] = []
        for input in descriptor.inputs {
            guard let inBuffer = buffers[input.bufferName] else {
                throw ElementHandlerError.message("No such buffer: \(input.bufferName)")
            }
            inputs.append(BluetoothInput(char: input.char, conversion: input.conversion, buffer: inBuffer))
        }
        
        self.init(device: device, inputList: inputs, configList: descriptor.configs)
    }
}

// Mark: - Constants
public let latestSupportedFileVersion = SemanticVersion(major: 1, minor: 8, patch: 0)

// Mark: - Phyphox Element Handler

/// Element handler for the phyphox root element. Produces Instances of `Experiment`.
final class PhyphoxElementHandler: ResultElementHandler, LookupElementHandler {
    var results = [Experiment]()

    var childHandlers: [String: ElementHandler]

    private let titleHandler = TextElementHandler()
    private let stateTitleHandler = TextElementHandler()
    private let categoryHandler = TextElementHandler()
    private let descriptionHandler = MultilineTextElementHandler()
    private let iconHandler = IconElementHandler()
    private let colorHandler = ColorElementHandler()
    private let linkHandler = LinkElementHandler()
    private let dataContainersHandler = DataContainersElementHandler()
    private let translationsHandler = TranslationsElementHandler()
    private let inputHandler = InputElementHandler()
    private let outputHandler = OutputElementHandler()
    private let analysisHandler = AnalysisElementHandler()
    private let viewsHandler = ViewsElementHandler()
    private let exportHandler = ExportElementHandler()

    init() {
        childHandlers = ["title": titleHandler, "state-title": stateTitleHandler, "category": categoryHandler, "description": descriptionHandler, "icon": iconHandler, "color": colorHandler, "link": linkHandler, "data-containers": dataContainersHandler, "translations": translationsHandler, "input": inputHandler, "output": outputHandler, "analysis": analysisHandler, "views": viewsHandler, "export": exportHandler]
    }

    private enum Attribute: String, AttributeKey {
        case locale
        case version
        case appleBan
    }

    func startElement(attributes: AttributeContainer) throws {}

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)
        
        let locale = attributes.optionalString(for: .locale) ?? "en"

        let versionString = try attributes.string(for: .version)
        
        let appleBan = try attributes.optionalValue(for: .appleBan) ?? false

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
        
        let stateTitle = try stateTitleHandler.expectOptionalResult()

        guard let category = try categoryHandler.expectOptionalResult() ?? translations?.selectedTranslation?.categoryString else {
            throw ElementHandlerError.missingElement("category")
        }

        let description = try descriptionHandler.expectOptionalResult() ?? translations?.selectedTranslation?.descriptionString ?? ""
        
        let maxIndex = title.index(title.startIndex, offsetBy: min(2, title.count))
        let icon = try iconHandler.expectOptionalResult() ?? .string(String(title[..<maxIndex]).uppercased())
        
        let color = try colorHandler.expectOptionalResult()
        
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

        let sensorInputs = inputDescriptor?.sensors.map { ExperimentSensorInput(descriptor: $0, buffers: buffers) } ?? []
        let gpsInputs = inputDescriptor?.location.map { ExperimentGPSInput(descriptor: $0, buffers: buffers) } ?? []
        let audioInputs = try inputDescriptor?.audio.map { try ExperimentAudioInput(descriptor: $0, buffers: buffers) } ?? []
        
        let audioOutput = try makeAudioOutput(from: outputDescriptor?.audioOutput, buffers: buffers)
        
        var bluetoothDevices: [ExperimentBluetoothDevice] = []
        var bluetoothInputs: [ExperimentBluetoothInput] = []
        var bluetoothOutputs: [ExperimentBluetoothOutput] = []
        var bluetoothDeviceMap: [String:ExperimentBluetoothDevice] = [:]
        
        func getBluetoothDeviceForId(id: String?, name: String?, uuid: CBUUID?, autoConnect: Bool) -> ExperimentBluetoothDevice {
            let bluetoothDevice: ExperimentBluetoothDevice
            if let id = id, id != "" {
                if let device = bluetoothDeviceMap[id] {
                    bluetoothDevice = device
                } else {
                    bluetoothDevice = ExperimentBluetoothDevice(id: id, name: name, uuid: uuid, autoConnect: autoConnect)
                    bluetoothDeviceMap[id] = bluetoothDevice
                    bluetoothDevices.append(bluetoothDevice)
                }
            } else {
                bluetoothDevice = ExperimentBluetoothDevice(id: nil, name: name, uuid: uuid, autoConnect: autoConnect)
                bluetoothDevices.append(bluetoothDevice)
            }
            return bluetoothDevice
        }
        
        if let descriptors = inputDescriptor?.bluetooth {
            for descriptor in descriptors {
                let device = getBluetoothDeviceForId(id: descriptor.id, name: descriptor.name, uuid: descriptor.uuid, autoConnect: descriptor.autoConnect)
                bluetoothInputs.append(try ExperimentBluetoothInput(device: device, descriptor: descriptor, buffers: buffers) )
            }
        }
        if let descriptors = outputDescriptor?.bluetooth {
            for descriptor in descriptors {
                let device = getBluetoothDeviceForId(id: descriptor.id, name: descriptor.name, uuid: descriptor.uuid, autoConnect: descriptor.autoConnect)
                bluetoothOutputs.append(try ExperimentBluetoothOutput(device: device, descriptor: descriptor, buffers: buffers) )
            }
        }

        let exportDescriptor = try exportHandler.expectOptionalResult() ?? []
        let export = try makeExport(from: exportDescriptor, buffers: buffers)

        let viewCollectionDescriptors = try viewsHandler.expectOptionalResult()

        let viewDescriptors = try viewCollectionDescriptors?.map { ExperimentViewCollectionDescriptor(label: $0.label, translation: translations, views: try $0.views.map { try makeViewDescriptor(from: $0, buffers: buffers, translations: translations) })  }

        let experiment = Experiment(title: title, stateTitle: stateTitle, description: description, links: links, category: category, icon: icon, color: color, persistentStorageURL: experimentPersistentStorageURL, appleBan: appleBan, translation: translations, buffers: buffers, sensorInputs: sensorInputs, gpsInputs: gpsInputs, audioInputs: audioInputs, audioOutput: audioOutput, bluetoothDevices: bluetoothDevices, bluetoothInputs: bluetoothInputs, bluetoothOutputs: bluetoothOutputs, viewDescriptors: viewDescriptors, analysis: analysis, export: export)

        results.append(experiment)
    }

    /// MARK: - Helpers required for the initialization of an `Experiment` instance and for the creation of properties of `Experiment` from intermediate element handler results.

    private func makeViewDescriptor(from descriptor: ViewElementDescriptor, buffers: [String: DataBuffer], translations: ExperimentTranslationCollection?) throws -> ViewDescriptor {
        switch descriptor {
        case .separator(let descriptor):
            return SeparatorViewDescriptor(height: descriptor.height, color: descriptor.color)
        case .info(let descriptor):
            return InfoViewDescriptor(label: descriptor.label, color: descriptor.color, translation: translations)
        case .value(let descriptor):
            guard let buffer = buffers[descriptor.inputBufferName] else {
                throw ElementHandlerError.missingElement("data-container")
            }

            return ValueViewDescriptor(label: descriptor.label, color: descriptor.color, translation: translations, size: descriptor.size, scientific: descriptor.scientific, precision: descriptor.precision, unit: descriptor.unit, factor: descriptor.factor, buffer: buffer, mappings: descriptor.mappings)
            
        case .edit(let descriptor):
            guard let buffer = buffers[descriptor.outputBufferName] else {
                throw ElementHandlerError.missingElement("data-container")
            }

            if buffer.isEmpty {
                buffer.append(descriptor.defaultValue)
            }

            return EditViewDescriptor(label: descriptor.label, translation: translations, signed: descriptor.signed, decimal: descriptor.decimal, unit: descriptor.unit, factor: descriptor.factor, min: descriptor.min, max: descriptor.max, defaultValue: descriptor.defaultValue, buffer: buffer)

        case .button(let descriptor):
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

        case .graph(let descriptor):
            let xBuffers = try descriptor.xInputBufferNames.map({ name -> DataBuffer? in
                if name == nil {
                    return nil
                }
                guard let buffer = buffers[name!] else {
                    throw ElementHandlerError.missingElement("data-container \(name!) for graph \(descriptor.label)")
                }
                return buffer
            })
            
            let yBuffers = try descriptor.yInputBufferNames.map({ name -> DataBuffer in
                guard let buffer = buffers[name] else {
                    throw ElementHandlerError.missingElement("data-container \(name) for graph \(descriptor.label)")
                }
                return buffer
            })
            
            let zBuffers = try descriptor.zInputBufferNames.map({ name -> DataBuffer? in
                if name == nil {
                    return nil
                }
                guard let buffer = buffers[name!] else {
                    throw ElementHandlerError.missingElement("data-container \(name!) for graph \(descriptor.label)")
                }
                return buffer
            })

            return GraphViewDescriptor(label: descriptor.label, translation: translations, xLabel: descriptor.xLabel, yLabel: descriptor.yLabel, zLabel: descriptor.zLabel, xUnit: descriptor.xUnit, yUnit: descriptor.yUnit, zUnit: descriptor.zUnit, xInputBuffers: xBuffers, yInputBuffers: yBuffers, zInputBuffers: zBuffers, logX: descriptor.logX, logY: descriptor.logY, logZ: descriptor.logZ, xPrecision: descriptor.xPrecision, yPrecision: descriptor.yPrecision, zPrecision: descriptor.zPrecision, scaleMinX: descriptor.scaleMinX, scaleMaxX: descriptor.scaleMaxX, scaleMinY: descriptor.scaleMinY, scaleMaxY: descriptor.scaleMaxY, scaleMinZ: descriptor.scaleMinZ, scaleMaxZ: descriptor.scaleMaxZ, minX: descriptor.minX, maxX: descriptor.maxX, minY: descriptor.minY, maxY: descriptor.maxY, minZ: descriptor.minZ, maxZ: descriptor.maxZ, aspectRatio: descriptor.aspectRatio, partialUpdate: descriptor.partialUpdate, history: descriptor.history, style: descriptor.style, lineWidth: descriptor.lineWidth, color: descriptor.color, mapWidth: descriptor.mapWidth, colorMap: descriptor.colorMap)
        }
    }

    private func makeAudioOutput(from descriptor: AudioOutputDescriptor?, buffers: [String: DataBuffer]) throws -> ExperimentAudioOutput? {

        if let audioOutput = descriptor {
            guard let buffer = buffers[audioOutput.inputBufferName] else {
                throw ElementHandlerError.missingElement("data-container")
            }

            return ExperimentAudioOutput(sampleRate: audioOutput.rate, loop: audioOutput.loop, dataSource: buffer)
        }
        return nil
    }

    private func makeExport(from descriptors: [ExportSetDescriptor], buffers: [String: DataBuffer]) throws -> ExperimentExport {
        let sets = try descriptors.map { descriptor -> ExperimentExportSet in
            let dataSets = try descriptor.dataSets.map { set -> (String, DataBuffer) in
                guard let buffer = buffers[set.bufferName] else {
                    throw ElementHandlerError.missingElement("data-container")
                }

                return (set.name, buffer)
            }

            return ExperimentExportSet(name: descriptor.name, data: dataSets)
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

            //Only use memory for now
            /*
            if bufferSize == 0 && !analysisInputBufferNames.contains(name) {
                let bufferURL = experimentPersistentStorageURL.appendingPathComponent(name).appendingPathExtension(bufferContentsFileExtension)

                storageType = .hybrid(memorySize: 5000, persistentStorageLocation: bufferURL)
            }
            else {
             */
                storageType = .memory(size: bufferSize)
            //}

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
