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
    convenience init(descriptor: SensorInputDescriptor, timeReference: ExperimentTimeReference, buffers: [String: DataBuffer]) {
        let xBuffer = descriptor.buffer(for: "x", from: buffers)
        let yBuffer = descriptor.buffer(for: "y", from: buffers)
        let zBuffer = descriptor.buffer(for: "z", from: buffers)
        let tBuffer = descriptor.buffer(for: "t", from: buffers)
        let absBuffer = descriptor.buffer(for: "abs", from: buffers)
        let accuracyBuffer = descriptor.buffer(for: "accuracy", from: buffers)

        self.init(sensorType: descriptor.sensor, timeReference: timeReference, calibrated: true, motionSession: MotionSession.sharedSession(), rate: descriptor.rate, rateStrategy: descriptor.rateStrategy!, average: descriptor.average, stride: descriptor.stride, ignoreUnavailable: descriptor.ignoreUnavailable, xBuffer: xBuffer, yBuffer: yBuffer, zBuffer: zBuffer, tBuffer: tBuffer, absBuffer: absBuffer, accuracyBuffer: accuracyBuffer)
    }
}

private extension ExperimentDepthInput {
    convenience init(descriptor: DepthInputDescriptor, timeReference: ExperimentTimeReference, buffers: [String: DataBuffer]) {
        let zBuffer = descriptor.buffer(for: "z", from: buffers)
        let tBuffer = descriptor.buffer(for: "t", from: buffers)

        self.init(timeReference: timeReference, zBuffer: zBuffer, tBuffer: tBuffer, mode: descriptor.mode, x1: descriptor.x1, x2: descriptor.x2, y1: descriptor.y1, y2: descriptor.y2, smooth: descriptor.smooth)
    }
}

private extension ExperimentCameraInput {
    convenience init(descriptor: CameraInputDescriptor, timeReference: ExperimentTimeReference, buffers: [String: DataBuffer]) {
        let tBuffer = descriptor.buffer(for: "t", from: buffers)
        let luminanceBuffer = descriptor.buffer(for: "luminance", from: buffers)
        let lumaBuffer = descriptor.buffer(for: "luma", from: buffers)
        let hueBuffer = descriptor.buffer(for: "hue", from: buffers)
        let saturationBuffer = descriptor.buffer(for: "saturation", from: buffers)
        let valueBuffer = descriptor.buffer(for: "value", from: buffers)
        let threasholdBuffer = descriptor.buffer(for: "threshold", from: buffers)
        let shutterSpeedBuffer = descriptor.buffer(for: "shutterSpeed", from: buffers)
        let isoBuffer = descriptor.buffer(for: "iso", from: buffers)
        let apertureBuffer = descriptor.buffer(for: "aperture", from: buffers)

        self.init(timeReference: timeReference, luminanceBuffer: luminanceBuffer, lumaBuffer: lumaBuffer, hueBuffer: hueBuffer, saturationBuffer: saturationBuffer, valueBuffer: valueBuffer, thresholdBuffer: threasholdBuffer, shutterSpeedBuffer: shutterSpeedBuffer, isoBuffer: isoBuffer, apertureBuffer: apertureBuffer, tBuffer: tBuffer, x1: descriptor.x1, x2: descriptor.x2, y1: descriptor.y1, y2: descriptor.y2, autoExposure: descriptor.autoExposure, aeStrategy: descriptor.aeStrategy, locked: descriptor.locked, feature: descriptor.feature)
    }
}

private extension ExperimentGPSInput {
    convenience init(descriptor: LocationInputDescriptor, timeReference: ExperimentTimeReference, buffers: [String: DataBuffer]) {
        let latBuffer = descriptor.buffer(for: "lat", from: buffers)
        let lonBuffer = descriptor.buffer(for: "lon", from: buffers)
        let zBuffer = descriptor.buffer(for: "z", from: buffers)
        let zWgs84Buffer = descriptor.buffer(for: "zwgs84", from: buffers)
        let vBuffer = descriptor.buffer(for: "v", from: buffers)
        let dirBuffer = descriptor.buffer(for: "dir", from: buffers)
        let accuracyBuffer = descriptor.buffer(for: "accuracy", from: buffers)
        let zAccuracyBuffer = descriptor.buffer(for: "zAccuracy", from: buffers)
        let tBuffer = descriptor.buffer(for: "t", from: buffers)
        let statusBuffer = descriptor.buffer(for: "status", from: buffers)
        let satellitesBuffer = descriptor.buffer(for: "satellites", from: buffers)

        self.init(latBuffer: latBuffer, lonBuffer: lonBuffer, zBuffer: zBuffer, zWgs84Buffer: zWgs84Buffer, vBuffer: vBuffer, dirBuffer: dirBuffer, accuracyBuffer: accuracyBuffer, zAccuracyBuffer: zAccuracyBuffer, tBuffer: tBuffer, statusBuffer: statusBuffer, satellitesBuffer: satellitesBuffer, timeReference: timeReference)
    }
}

private extension ExperimentAudioInput {
    init(descriptor: AudioInputDescriptor, buffers: [String: DataBuffer]) throws {
        guard let outBuffer = (descriptor.buffer(for: "output", from: buffers) ?? descriptor.buffer(for: "out", from: buffers)) else {
            throw ElementHandlerError.missingAttribute("output")
        }

        let sampleRateBuffer = descriptor.buffer(for: "rate", from: buffers)

        self.init(sampleRate: descriptor.rate, outBuffer: outBuffer, sampleRateInfoBuffer: sampleRateBuffer, appendData: descriptor.appendData)
    }
}

private extension ExperimentBluetoothInput {
    convenience init(device: ExperimentBluetoothDevice, descriptor: BluetoothInputBlockDescriptor, buffers: [String: DataBuffer], timeReference: ExperimentTimeReference) throws {
        
        var outputs: [BluetoothOutput] = []
        for output in descriptor.outputs {
            guard let outBuffer = buffers[output.bufferName] else {
                throw ElementHandlerError.message("No such buffer: \(output.bufferName)")
            }
            outputs.append(BluetoothOutput(char: output.char, conversion: output.conversion, buffer: outBuffer, extra: output.extra))
        }
        
        self.init(device: device, mode: descriptor.mode, outputList: outputs, configList: descriptor.configs, subscribeOnStart: descriptor.subscribeOnStart, rate: descriptor.rate, timeReference: timeReference)
    }
}

private extension ExperimentBluetoothOutput {
    convenience init(device: ExperimentBluetoothDevice, descriptor: BluetoothOutputBlockDescriptor, buffers: [String: DataBuffer]) throws {
        
        var inputs: [BluetoothInput] = []
        for input in descriptor.inputs {
            guard let inBuffer = buffers[input.bufferName] else {
                throw ElementHandlerError.message("No such buffer: \(input.bufferName)")
            }
            inputs.append(BluetoothInput(char: input.char, conversion: input.conversion, offset: input.offset, buffer: inBuffer, keep: input.keep))
        }
        
        self.init(device: device, inputList: inputs, configList: descriptor.configs)
    }
}

// Mark: - Constants
public let latestSupportedFileVersion = SemanticVersion(major: 1, minor: 19, patch: 0)

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
    private let networkHandler = NetworkElementHandler()
    private let analysisHandler = AnalysisElementHandler()
    private let viewsHandler = ViewsElementHandler()
    private let exportHandler = ExportElementHandler()
    private let eventsHandler = EventsElementHandler()

    init() {
        childHandlers = ["title": titleHandler, "state-title": stateTitleHandler, "category": categoryHandler, "description": descriptionHandler, "icon": iconHandler, "color": colorHandler, "link": linkHandler, "data-containers": dataContainersHandler, "translations": translationsHandler, "input": inputHandler, "output": outputHandler, "network": networkHandler, "analysis": analysisHandler, "views": viewsHandler, "export": exportHandler, "events": eventsHandler]
    }

    private enum Attribute: String, AttributeKey {
        case locale
        case version
        case appleBan
        case isLink
    }

    func startElement(attributes: AttributeContainer) throws {}

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)
        
        let locale = attributes.optionalString(for: .locale) ?? "en"

        let versionString = try attributes.string(for: .version)
        
        let appleBan = try attributes.optionalValue(for: .appleBan) ?? false
        
        let isLink = try attributes.optionalValue(for: .isLink) ?? false

        guard let version = SemanticVersion(string: versionString) else {
            throw ElementHandlerError.unexpectedAttributeValue("version")
        }

        guard version <= latestSupportedFileVersion else {
            throw ElementHandlerError.message("File version \(versionString) is not supported")
        }

        let translations = try translationsHandler.expectOptionalResult().map { ExperimentTranslationCollection(translations: $0, defaultLanguageCode: locale) } ?? ExperimentTranslationCollection(translations: [:], defaultLanguageCode: "en")

        guard let title = try titleHandler.expectOptionalResult() ?? translations.selectedTranslation?.titleString else {
            throw ElementHandlerError.missingElement("title")
        }
        
        let stateTitle = try stateTitleHandler.expectOptionalResult()

        guard let category = try categoryHandler.expectOptionalResult() ?? translations.selectedTranslation?.categoryString else {
            throw ElementHandlerError.missingElement("category")
        }

        let description = try descriptionHandler.expectOptionalResult() ?? translations.selectedTranslation?.descriptionString ?? ""
        
        let maxIndex = title.index(title.startIndex, offsetBy: min(2, title.count))
        let icon = try iconHandler.expectOptionalResult() ?? .string(String(title[..<maxIndex]).uppercased())
        
        let color = try colorHandler.expectOptionalResult()
        
        let links = linkHandler.results

        let dataContainersDescriptor = try dataContainersHandler.expectOptionalResult()
        let analysisDescriptor = try analysisHandler.expectOptionalResult() ?? AnalysisDescriptor(sleep: 0, dynamicSleepName: nil, onUserInput: false, requireFillName: nil, requireFillThreshold: 1, requireFillDynamicName: nil, timedRun: false, timedRunStartDelay: 3, timedRunStopDelay: 10, modules: [])

        let analysisInputBufferNames = getInputBufferNames(from: analysisDescriptor)

        let buffers: [String : DataBuffer]
        if let dataContainersDescriptor = dataContainersDescriptor {
            buffers = try makeBuffers(from: dataContainersDescriptor, analysisInputBufferNames: analysisInputBufferNames)
        } else {
            buffers = [String : DataBuffer]()
        }

        let timeReference = ExperimentTimeReference()
        if let eventsDescriptor = try eventsHandler.expectOptionalResult() {
            for (type, event) in zip(eventsDescriptor.types, eventsDescriptor.events) {
                timeReference.timeMappings.append(ExperimentTimeReference.TimeMapping(event: type, experimentTime: event.experimentTime, eventTime: 0.0, systemTime: event.systemTime))
            }
        }

        let inputDescriptor = try inputHandler.expectOptionalResult()
        let outputDescriptor = try outputHandler.expectOptionalResult()

        let sensorInputs = inputDescriptor?.sensors.map { ExperimentSensorInput(descriptor: $0.defaults(forVersion: version), timeReference: timeReference, buffers: buffers) } ?? []
        let depthInputs = inputDescriptor?.depth.map { ExperimentDepthInput(descriptor: $0, timeReference: timeReference, buffers: buffers)}
        if depthInputs != nil && depthInputs!.count > 1 {
            throw ElementHandlerError.message("Depth is only allowed once.")
        }
        let depthInput = depthInputs?.first
        
        let cameraInputs = inputDescriptor?.camera.map {ExperimentCameraInput(descriptor: $0, timeReference: timeReference, buffers: buffers) }
        if cameraInputs != nil && cameraInputs!.count > 1 {
            throw ElementHandlerError.message("Camera is only allowed once.")
        }
        let cameraInput = cameraInputs?.first
        
        let gpsInputs = inputDescriptor?.location.map { ExperimentGPSInput(descriptor: $0, timeReference: timeReference, buffers: buffers) } ?? []
        let audioInputs = try inputDescriptor?.audio.map { try ExperimentAudioInput(descriptor: $0, buffers: buffers) } ?? []
        
        let audioOutput = try makeAudioOutput(from: outputDescriptor?.audioOutput, buffers: buffers)
        
        let analysisModules = try analysisDescriptor.modules.map({ try ExperimentAnalysisFactory.analysisModule(from: $1, for: $0, buffers: buffers) })
        let analysis = ExperimentAnalysis(modules: analysisModules, sleep: analysisDescriptor.sleep, dynamicSleep: analysisDescriptor.dynamicSleepName.map { buffers[$0] } ?? nil, onUserInput: analysisDescriptor.onUserInput, requireFill: analysisDescriptor.requireFillName.map { buffers[$0] } ?? nil, requireFillThreshold: analysisDescriptor.requireFillThreshold, requireFillDynamic: analysisDescriptor.requireFillDynamicName.map { buffers[$0] } ?? nil, timedRun: analysisDescriptor.timedRun, timedRunStartDelay: analysisDescriptor.timedRunStartDelay, timedRunStopDelay: analysisDescriptor.timedRunStopDelay, timeReference: timeReference, sensorInputs: sensorInputs, audioInputs: audioInputs)
        
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
                bluetoothInputs.append(try ExperimentBluetoothInput(device: device, descriptor: descriptor, buffers: buffers, timeReference: timeReference) )
            }
        }
        if let descriptors = outputDescriptor?.bluetooth {
            for descriptor in descriptors {
                let device = getBluetoothDeviceForId(id: descriptor.id, name: descriptor.name, uuid: descriptor.uuid, autoConnect: descriptor.autoConnect)
                bluetoothOutputs.append(try ExperimentBluetoothOutput(device: device, descriptor: descriptor, buffers: buffers) )
            }
        }
        
        var networkConnections: [NetworkConnection] = []
        if let networkConnectionDescriptors = try networkHandler.expectOptionalResult() {
            for descriptor in networkConnectionDescriptors {
                var send: [String: NetworkSendableData] = [:]
                for item in descriptor.send {
                    switch item.type {
                    case .buffer:
                        guard let buffer = buffers[item.name] else {
                            throw ElementHandlerError.missingElement("data-container")
                        }
                        send[item.id] = NetworkSendableData(source: .Buffer(buffer, keep: item.keep), additionalAttributes: item.additionalAttributes)
                    case .meta:
                        let metadata: NetworkSendableData.Source
                        switch (item.name) {
                        case "uniqueID": metadata = .Metadata(.uniqueId)
                        case "version": metadata = .Metadata(.version)
                        case "build": metadata = .Metadata(.build)
                        case "fileFormat": metadata = .Metadata(.fileFormat)
                        case "deviceModel": metadata = .Metadata(.deviceModel)
                        case "deviceBrand": metadata = .Metadata(.deviceBrand)
                        case "deviceBoard": metadata = .Metadata(.deviceBoard)
                        case "deviceManufacturer": metadata = .Metadata(.deviceManufacturer)
                        case "deviceBaseOS": metadata = .Metadata(.deviceBaseOS)
                        case "deviceCodename": metadata = .Metadata(.deviceCodename)
                        case "deviceRelease": metadata = .Metadata(.deviceRelease)
                        case "depthFrontSensor": metadata = .Metadata(.depthFrontSensor)
                        case "depthFrontResolution": metadata = .Metadata(.depthFrontResolution)
                        case "depthFrontRate": metadata = .Metadata(.depthFrontRate)
                        case "depthBackSensor": metadata = .Metadata(.depthBackSensor)
                        case "depthBackResolution": metadata = .Metadata(.depthBackResolution)
                        case "depthBackRate": metadata = .Metadata(.depthBackRate)
                        default:
                            func matchSensor(name: String, sensor: SensorType) throws -> NetworkSendableData.Source? {
                                if name.starts(with: sensor.description) {
                                    let sensorMetadata = name.dropFirst(sensor.description.count)
                                    let sensorMetadataMatch = sensorMetadata.prefix(1).lowercased() + sensorMetadata.dropFirst()
                                    guard let sensorMeta = SensorMetadata(rawValue: String(sensorMetadataMatch)) else {
                                        throw ElementHandlerError.message("Unknown metadata name \(name)")
                                    }
                                    return .Metadata(.sensor(sensor, sensorMeta))
                                }
                                return nil
                            }
                            if let res = try matchSensor(name: item.name, sensor: SensorType.accelerometer) {
                                metadata = res
                            } else if let res = try matchSensor(name: item.name, sensor: SensorType.gyroscope) {
                                metadata = res
                            } else if let res = try matchSensor(name: item.name, sensor: SensorType.humidity) {
                                metadata = res
                            } else if let res = try matchSensor(name: item.name, sensor: SensorType.light) {
                                metadata = res
                            } else if let res = try matchSensor(name: item.name, sensor: SensorType.linearAcceleration) {
                                metadata = res
                            } else if let res = try matchSensor(name: item.name, sensor: SensorType.magneticField) {
                                metadata = res
                            } else if let res = try matchSensor(name: item.name, sensor: SensorType.pressure) {
                                metadata = res
                            } else if let res = try matchSensor(name: item.name, sensor: SensorType.proximity) {
                                metadata = res
                            } else if let res = try matchSensor(name: item.name, sensor: SensorType.temperature) {
                                metadata = res
                            } else if let res = try matchSensor(name: item.name, sensor: SensorType.attitude) {
                                metadata = res
                            } else if let res = try matchSensor(name: item.name, sensor: SensorType.gravity) {
                                metadata = res
                            } else {
                                throw ElementHandlerError.message("Unknown metadata name \(item.name)")
                            }
                        }
                        send[item.id] = NetworkSendableData(source: metadata, additionalAttributes: item.additionalAttributes)
                    case .time:
                        send[item.id] = NetworkSendableData(source: .Time(timeReference), additionalAttributes: item.additionalAttributes)
                    }
                    
                }
                var receive: [String: NetworkReceivableData] = [:]
                for item in descriptor.receive {
                    guard let buffer = buffers[item.name] else {
                        throw ElementHandlerError.missingElement("data-container")
                    }
                    receive[item.id] = NetworkReceivableData(buffer: buffer, append: item.append)
                }
                networkConnections.append(NetworkConnection(id: descriptor.id, privacyURL: descriptor.privacyURL, address: descriptor.address, discovery: descriptor.discovery, autoConnect: descriptor.autoConnect, service: descriptor.service, conversion: descriptor.conversion, send: send, receive: receive, interval: descriptor.interval))
            }
        }

        let exportDescriptor = try exportHandler.expectOptionalResult() ?? []
        let export = try makeExport(from: exportDescriptor, buffers: buffers)

        let viewCollectionDescriptors = try viewsHandler.expectOptionalResult()

        let viewDescriptors = try viewCollectionDescriptors?.map { ExperimentViewCollectionDescriptor(label: $0.label, translation: translations, views: try $0.views.map { try makeViewDescriptor(from: $0, timeReference: timeReference, buffers: buffers, translations: translations) })  }

        if !isLink {
            guard viewDescriptors != nil else {
                throw ElementHandlerError.missingElement("view")
            }
        }
        
        let experiment = Experiment(title: title, stateTitle: stateTitle, description: description, links: links, category: category, icon: icon, color: color, appleBan: appleBan, isLink: isLink, translation: translations, buffers: buffers, timeReference: timeReference, sensorInputs: sensorInputs, depthInput: depthInput, cameraInput: cameraInput, gpsInputs: gpsInputs, audioInputs: audioInputs, audioOutput: audioOutput, bluetoothDevices: bluetoothDevices, bluetoothInputs: bluetoothInputs, bluetoothOutputs: bluetoothOutputs, networkConnections: networkConnections, viewDescriptors: viewDescriptors, analysis: analysis, export: export)

        results.append(experiment)
    }

    /// MARK: - Helpers required for the initialization of an `Experiment` instance and for the creation of properties of `Experiment` from intermediate element handler results.

    private func makeViewDescriptor(from descriptor: ViewElementDescriptor, timeReference: ExperimentTimeReference, buffers: [String: DataBuffer], translations: ExperimentTranslationCollection?) throws -> ViewDescriptor {
        switch descriptor {
        case .separator(let descriptor):
            return SeparatorViewDescriptor(height: descriptor.height, color: descriptor.color)
        case .image(let descriptor):
            return ImageViewDescriptor(src: descriptor.src, scale: descriptor.scale, darkFilter: descriptor.darkFilter, lightFilter: descriptor.lightFilter)
        case .info(let descriptor):
            return InfoViewDescriptor(label: descriptor.label, color: descriptor.color, fontSize: descriptor.fontSize, align: descriptor.align, bold: descriptor.bold, italic: descriptor.italic, translation: translations)
        case .value(let descriptor):
            guard let buffer = buffers[descriptor.inputBufferName] else {
                throw ElementHandlerError.missingElement("data-container")
            }

            return ValueViewDescriptor(label: descriptor.label, color: descriptor.color, translation: translations, size: descriptor.size, scientific: descriptor.scientific, precision: descriptor.precision, unit: descriptor.unit, factor: descriptor.factor, buffer: buffer, mappings: descriptor.mappings, positiveUnit: descriptor.positiveUnit, negativeUnit: descriptor.negativeUnit, gpsFormat: descriptor.gpsFormat)
            
        case .edit(let descriptor):
            guard let buffer = buffers[descriptor.outputBufferName] else {
                throw ElementHandlerError.missingElement("data-container")
            }

            if buffer.isEmpty {
                buffer.append(descriptor.defaultValue)
            }

            return EditViewDescriptor(label: descriptor.label, translation: translations, signed: descriptor.signed, decimal: descriptor.decimal, unit: descriptor.unit, factor: descriptor.factor, min: descriptor.min, max: descriptor.max, defaultValue: descriptor.defaultValue, buffer: buffer)

        case .button(let descriptor):
            let dataFlow = try descriptor.dataFlow.map { flow -> (ExperimentAnalysisDataInput, DataBuffer) in
                guard let outputBuffer = buffers[flow.outputBufferName] else {
                    throw ElementHandlerError.missingElement("data-container")
                }

                let input: ExperimentAnalysisDataInput

                switch flow.input {
                case .buffer(let bufferName):
                    guard let buffer = buffers[bufferName] else {
                        throw ElementHandlerError.missingElement("data-container")
                    }

                    input = .buffer(buffer: buffer, data: MutableDoubleArray(data: []), usedAs: "", keep: false)
                case .value(let value):
                    input = .value(value: value, usedAs: "")
                case .clear:
                    input = .buffer(buffer: emptyBuffer, data: MutableDoubleArray(data: []), usedAs: "", keep: false)
                }

                return (input, outputBuffer)
            }
            
            let buffer: DataBuffer?
            if descriptor.dynamicLabel != "" {
                buffer = buffers[descriptor.dynamicLabel]
                if(buffer == nil){
                    throw ElementHandlerError.missingElement("data-container")
                }
            } else {
                buffer = nil
            }
            
            return ButtonViewDescriptor(label: descriptor.label, translation: translations, dataFlow: dataFlow, triggers: descriptor.triggers, mappings: descriptor.mappings, buffer: buffer)

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

            return GraphViewDescriptor(label: descriptor.label, translation: translations, xLabel: descriptor.xLabel, yLabel: descriptor.yLabel, zLabel: descriptor.zLabel, xUnit: descriptor.xUnit, yUnit: descriptor.yUnit, zUnit: descriptor.zUnit, yxUnit: descriptor.yxUnit, timeReference: timeReference, timeOnX: descriptor.timeOnX, timeOnY: descriptor.timeOnY, systemTime: descriptor.systemTime, linearTime: descriptor.linearTime, hideTimeMarkers: descriptor.hideTimeMarkers, xInputBuffers: xBuffers, yInputBuffers: yBuffers, zInputBuffers: zBuffers, logX: descriptor.logX, logY: descriptor.logY, logZ: descriptor.logZ, xPrecision: descriptor.xPrecision, yPrecision: descriptor.yPrecision, zPrecision: descriptor.zPrecision, suppressScientificNotation: descriptor.suppressScientificNotation, scaleMinX: descriptor.scaleMinX, scaleMaxX: descriptor.scaleMaxX, scaleMinY: descriptor.scaleMinY, scaleMaxY: descriptor.scaleMaxY, scaleMinZ: descriptor.scaleMinZ, scaleMaxZ: descriptor.scaleMaxZ, minX: descriptor.minX, maxX: descriptor.maxX, minY: descriptor.minY, maxY: descriptor.maxY, minZ: descriptor.minZ, maxZ: descriptor.maxZ, followX: descriptor.followX, aspectRatio: descriptor.aspectRatio, partialUpdate: descriptor.partialUpdate, history: descriptor.history, style: descriptor.style, lineWidth: descriptor.lineWidth, color: descriptor.color, mapWidth: descriptor.mapWidth, colorMap: descriptor.colorMap, showColorScale: descriptor.showColorScale)
        case .depthGUI(let descriptor):
            return DepthGUIViewDescriptor(label: descriptor.label, aspectRatio: descriptor.aspectRatio, translation: translations)
            
        case .switchView(let descriptor):
            guard let buffer = buffers[descriptor.outputBufferName] else {
                throw ElementHandlerError.missingElement("data-container")
            }
            
            if buffer.isEmpty {
                buffer.append(descriptor.defaultValue)
            }
            
            return SwitchViewDescriptor(label: descriptor.label, translation: translations, defaultValue: descriptor.defaultValue, buffer: buffer)
            
        case .dropdown(let descriptor):
            guard let buffer = buffers[descriptor.outputBufferName] else {
                throw ElementHandlerError.missingElement("data-container")
            }
            
            if buffer.isEmpty {
                buffer.append(descriptor.defaultValue)
            }
            
            return DropdownViewDescriptor(label: descriptor.label, defaultValue: descriptor.defaultValue, buffer: buffer, mappings: descriptor.mappings)
            
        case .slider(let descriptor):
            
            var outputBuffers : [SliderOutputValueType : DataBuffer] = [:]
            
            if(SliderType.Range == descriptor.type){
                
                guard let lowerValue = buffers[descriptor.lowerBufferName] else {
                    throw ElementHandlerError.missingElement("data-container")
                }
                
                guard let upperValue = buffers[descriptor.upperBufferName] else {
                    throw ElementHandlerError.missingElement("data-container")
                }
                
                outputBuffers[.LowerValue] = lowerValue
                outputBuffers[.UpperValue] = upperValue
                
            } else {
                
                guard let outputBufferName = descriptor.outputBufferName else {
                    throw ElementHandlerError.missingElement("data-container")
                }
                
                guard let outputBuffer = buffers[outputBufferName] else {
                    throw ElementHandlerError.missingElement("data-container")
                }
                
                if outputBuffer.isEmpty {
                    outputBuffer.append(descriptor.defaultValue)
                }
                
                outputBuffers[.Empty] = outputBuffer
                
            }
            
            return SliderViewDescriptor(label: descriptor.label, minValue: descriptor.minValue, maxValue: descriptor.maxValue, stepSize: descriptor.stepSize, defaultValue: descriptor.defaultValue, precision: descriptor.precision, outputBuffers: outputBuffers, type: descriptor.type, showValue: descriptor.showValue)
            
            
            
        case .camera(let descriptor):
            return CameraViewDescriptor(label: descriptor.label, exposureAdjustmentLevel: descriptor.exposureAdjustmentLevel,
                                        grayscale: descriptor.grayscale, markOverexposure: descriptor.markOverexposure, markUnderexposure: descriptor.markUnderexposure, showControls: descriptor.showControls, translation: translations)
            
        }
        
    }

    private func makeAudioOutput(from descriptor: AudioOutputDescriptor?, buffers: [String: DataBuffer]) throws -> ExperimentAudioOutput? {

        if let audioOutput = descriptor {
            let directBuffer: DataBuffer?
            var tones: [ExperimentAudioOutputTone] = []
            let noise: ExperimentAudioOutputNoise?
            
            if let inputBuffer = audioOutput.inputBufferName {
                directBuffer = buffers[inputBuffer]
                guard directBuffer != nil else {
                    throw ElementHandlerError.missingElement("data-container")
                }
            } else {
                directBuffer = nil
            }
            
            for toneDescriptor in audioOutput.tones {
                var frequency = AudioParameter.value(value: 440.0)
                var amplitude = AudioParameter.value(value: 1.0)
                var duration = AudioParameter.value(value: 1.0)
                
                for input in toneDescriptor.inputs {
                    let target: String
                    let parameter: AudioParameter
                    switch input {
                    case .buffer(name: let name, usedAs: let usedAs):
                        target = usedAs
                        guard let buffer = buffers[name] else {
                            throw ElementHandlerError.missingElement("data-container")
                        }
                        parameter = AudioParameter.buffer(buffer: buffer)
                    case .value(value: let value, usedAs: let usedAs):
                        target = usedAs
                        parameter = AudioParameter.value(value: value)
                    }
                    switch target {
                    case "frequency": frequency = parameter
                    case "amplitude": amplitude = parameter
                    case "duration": duration = parameter
                    default: throw ElementHandlerError.message("Invalid parameter for input of audio output tone.")
                    }
                }
                
                let tone = ExperimentAudioOutputTone(waveform: toneDescriptor.waveform, frequency: frequency, amplitude: amplitude, duration: duration)
                tones.append(tone)
            }
            
            var amplitude = AudioParameter.value(value: 1.0)
            var duration = AudioParameter.value(value: 1.0)
            
            if let noiseDescriptor = audioOutput.noise {
                for input in noiseDescriptor.inputs {
                    let target: String
                    let parameter: AudioParameter
                    switch input {
                    case .buffer(name: let name, usedAs: let usedAs):
                        target = usedAs
                        guard let buffer = buffers[name] else {
                            throw ElementHandlerError.missingElement("data-container")
                        }
                        parameter = AudioParameter.buffer(buffer: buffer)
                    case .value(value: let value, usedAs: let usedAs):
                        target = usedAs
                        parameter = AudioParameter.value(value: value)
                    }
                    switch target {
                    case "amplitude": amplitude = parameter
                    case "duration": duration = parameter
                    default: throw ElementHandlerError.message("Invalid parameter for input of audio output noise.")
                    }
                }
                noise = ExperimentAudioOutputNoise(amplitude: amplitude, duration: duration)
            } else {
                noise = nil
            }
            
            if directBuffer == nil && tones.count == 0 && noise == nil {
                throw ElementHandlerError.message("No inputs for audio output.")
            }
            
            return ExperimentAudioOutput(sampleRate: audioOutput.rate, loop: audioOutput.loop, normalize: audioOutput.normalize, directSource: directBuffer, tones: tones, noise: noise)
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

    private func makeBuffers(from descriptors: [BufferDescriptor], analysisInputBufferNames: Set<String>) throws -> [String: DataBuffer] {
        var buffers: [String: DataBuffer] = [:]

        for descriptor in descriptors {
            let bufferSize = descriptor.size
            let name = descriptor.name
            let staticBuffer = descriptor.staticBuffer
            let baseContents = descriptor.baseContents

            let buffer = try DataBuffer(name: name, size: bufferSize, baseContents: baseContents, static: staticBuffer)

            buffers[name] = buffer

        }

        return buffers
    }

    private func getInputBufferNames(from analysis: AnalysisDescriptor) -> Set<String> {
        let inputBufferNames = analysis.modules.flatMap({ $0.descriptor.inputs }).compactMap({ descriptor -> String? in
            switch descriptor {
            case .buffer(name: let name, usedAs: _, keep: _):
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
