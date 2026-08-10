//
//  InputElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreBluetooth

// This file contains element handlers for the `input` child element (and its child elements) of the `phyphox` root element.

struct SensorOutputDescriptor {
    let component: String?
    let bufferName: String
}

//The component tables of the input elements, mirroring the ioMapping arrays in Android's
//PhyphoxFile.java. They live here, next to the handlers that enforce them, so the component
//vocabulary is defined in one file only (the buffer wiring in PhyphoxElementHandler receives
//components already normalized to these names).
private let sensorComponents = ["x", "y", "z", "t", "abs", "accuracy"].map {
    AnalysisIOSlot(name: $0, asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
}
private let locationComponents = ["lat", "lon", "z", "zwgs84", "v", "dir", "t", "accuracy", "zAccuracy", "status", "satellites"].map {
    AnalysisIOSlot(name: $0, asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
}
private let audioComponents = [
    AnalysisIOSlot(name: "out", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1),
    AnalysisIOSlot(name: "rate", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
]
private let depthComponents = [
    AnalysisIOSlot(name: "z", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1),
    AnalysisIOSlot(name: "t", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
]
//wavelength is accepted on iOS only: part of the superseded calibration draft, never filled
//(see the camera element in spec/input.yml)
private let cameraComponents = ["t", "luma", "luminance", "hue", "saturation", "value", "threshold", "shutterSpeed", "iso", "aperture", "pixelPosition", "wavelength"].map {
    AnalysisIOSlot(name: $0, asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
}

protocol SensorDescriptor {
    var outputs: [SensorOutputDescriptor] { get }
}

private final class SensorOutputElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [SensorOutputDescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case component
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        guard !text.isEmpty else { throw ElementHandlerError.missingText }

        let attributes = attributes.attributes(keyedBy: Attribute.self)

        //An absent component attribute stays nil: whether an unnamed output is allowed - and
        //which component it then fills - is decided by the element's component table
        let component = attributes.optionalString(for: .component)
        results.append(SensorOutputDescriptor(component: component, bufferName: text))
    }

    func clear() {
        results.removeAll()
    }
}

struct LocationInputDescriptor: SensorDescriptor {
    let outputs: [SensorOutputDescriptor]
}

private final class LocationElementHandler: ResultElementHandler, LookupElementHandler {
    var results = [LocationInputDescriptor]()

    private let outputHandler = SensorOutputElementHandler()

    var childHandlers: [String : ElementHandler]

    init() {
        childHandlers = ["output": outputHandler]
    }

    func startElement(attributes: AttributeContainer) throws {}

    func endElement(text: String, attributes: AttributeContainer) throws {
        let outputs = try IOMappingValidation.validateComponents(element: "location", slots: locationComponents, outputs: outputHandler.results)
        results.append(LocationInputDescriptor(outputs: outputs))
    }
}

struct DepthInputDescriptor: SensorDescriptor {
    let mode: ExperimentDepthInput.DepthExtractionMode
    let x1: Float
    let x2: Float
    let y1: Float
    let y2: Float
    let smooth: Bool
    let outputs: [SensorOutputDescriptor]
}

private final class DepthElementHandler: ResultElementHandler, LookupElementHandler {
    var results = [DepthInputDescriptor]()

    private let outputHandler = SensorOutputElementHandler()

    var childHandlers: [String : ElementHandler]

    init() {
        childHandlers = ["output": outputHandler]
    }

    func startElement(attributes: AttributeContainer) throws {}
    
    private enum Attribute: String, AttributeKey {
        case mode
        case x1
        case x2
        case y1
        case y2
        case smooth
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let mode: ExperimentDepthInput.DepthExtractionMode = try attributes.optionalValue(for: .mode) ?? .closest
        let x1user: Float = try attributes.optionalValue(for: .x1) ?? 0.4
        let x2user: Float = try attributes.optionalValue(for: .x2) ?? 0.6
        let y1user: Float = try attributes.optionalValue(for: .y1) ?? 0.4
        let y2user: Float = try attributes.optionalValue(for: .y2) ?? 0.6

        //Careful: We will now switch from the user coordinate system to the camera coordinate system: x -> -y, y -> -x
        let x1 = 1.0-y1user
        let x2 = 1.0-y2user
        let y1 = 1.0-x1user
        let y2 = 1.0-x2user
        
        let smooth: Bool = try attributes.optionalValue(for: .smooth) ?? true

        //The depth output is required; an unnamed output fills it ("z")
        let outputs = try IOMappingValidation.validateComponents(element: "depth", slots: depthComponents, outputs: outputHandler.results)

        results.append(DepthInputDescriptor(mode: mode, x1: x1, x2: x2, y1: y1, y2: y2, smooth: smooth, outputs: outputs))
    }
}

struct CameraInputDescriptor: SensorDescriptor {
    let x1: Float
    let x2: Float
    let y1: Float
    let y2: Float
    let autoExposure: Bool
    let aeStrategy: ExperimentCameraInput.AutoExposureStrategy
    let aeFPSTarget: Double
    let locked: [String:Float?]
    let feature: CameraFeature
    let outputs: [SensorOutputDescriptor]
}

private final class CameraElementHandler: ResultElementHandler, LookupElementHandler {
    var results = [CameraInputDescriptor]()

    private let outputHandler = SensorOutputElementHandler()

    var childHandlers: [String : ElementHandler]

    init() {
        childHandlers = ["output": outputHandler]
    }

    func startElement(attributes: AttributeContainer) throws {}
    
    // spelling in the xml should match with it
    private enum Attribute: String, AttributeKey {
        case x1
        case x2
        case y1
        case y2
        case auto_exposure
        case aeStrategy
        case aeFPSTarget
        case locked
        case feature
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let x1user: Float = try attributes.optionalValue(for: .x1) ?? 0.4
        let x2user: Float = try attributes.optionalValue(for: .x2) ?? 0.6
        let y1user: Float = try attributes.optionalValue(for: .y1) ?? 0.4
        let y2user: Float = try attributes.optionalValue(for: .y2) ?? 0.6

        //Careful: We will now switch from the user coordinate system to the camera coordinate system: x -> -y, y -> -x
        let x1 = 1.0-y1user
        let x2 = 1.0-y2user
        let y1 = 1.0-x1user
        let y2 = 1.0-x2user
                
        let autoExposure: Bool = try attributes.optionalValue(for: .auto_exposure) ?? true
        
        let lockedStr: String = try attributes.optionalValue(for: .locked) ?? ""
        var locked: [String:Float?] = [:]
        for lockedSetting in lockedStr.split(separator: ",") {
            if lockedSetting.contains("=") {
                let parts = lockedSetting.split(separator: "=", maxSplits: 1)
                //Setting names are matched case-insensitively; storing them lowercased normalizes
                //them for every later lookup (enum-case-insensitive in phyphox-docs)
                let setting = String(parts[0]).trimmingCharacters(in: .whitespaces).lowercased()
                var value: Float? = nil
                if setting == "shutter_speed" && parts[1].contains("/") {
                    let fraction = parts[1].split(separator: "/")
                    let a = Float(String(fraction[0].trimmingCharacters(in: .whitespaces)))
                    let b = Float(String(fraction[1].trimmingCharacters(in: .whitespaces)))
                    if let a = a, let b = b {
                        value = a/b
                    }
                } else {
                    value = Float(String(parts[1].trimmingCharacters(in: .whitespaces)))
                }
                locked[setting] = value
            } else {
                locked[String(lockedSetting.trimmingCharacters(in: .whitespaces)).lowercased()] = nil
            }
        }
        
        //An invalid enumerated value is an error, only an absent attribute selects the default
        //(enum-invalid-value in phyphox-docs, matching Android)
        let feature_: CameraFeature = try attributes.optionalValue(for: .feature) ?? .PHOTOMETRIC

        let aeStrategy: ExperimentCameraInput.AutoExposureStrategy = try attributes.optionalValue(for: .aeStrategy) ?? .mean

        let aeFPSTarget: Double = try attributes.optionalValue(for: .aeFPSTarget) ?? 0.0

        let outputs = try IOMappingValidation.validateComponents(element: "camera", slots: cameraComponents, outputs: outputHandler.results)

        results.append(CameraInputDescriptor(x1: x1, x2: x2, y1: y1, y2: y2, autoExposure: autoExposure, aeStrategy: aeStrategy, aeFPSTarget: aeFPSTarget, locked: locked, feature: feature_, outputs: outputs))
    }
}

enum CameraFeature: String, CaseInsensitiveAttributeDecodable, CaseIterable {
    case PHOTOMETRIC = "photometric"
    case SPECTROSCOPY = "spectroscopy"
}

struct SensorInputDescriptor: SensorDescriptor {
    let sensor: SensorType
    let rate: Double
    let rateStrategy: ExperimentSensorInput.RateStrategy?
    let average: Bool
    let stride: Int
    let ignoreUnavailable: Bool

    let outputs: [SensorOutputDescriptor]
    
    func defaults(forVersion version: SemanticVersion) -> SensorInputDescriptor {
        let strategy: ExperimentSensorInput.RateStrategy
        if let rateStrategy = rateStrategy {
            strategy = rateStrategy
        } else {
            if version >= SemanticVersion(major: 1, minor: 14, patch: 0) {
                strategy = .auto
            } else {
                strategy = .limit
            }
        }
        return SensorInputDescriptor(sensor: sensor, rate: rate, rateStrategy: strategy, average: average, stride: stride, ignoreUnavailable: ignoreUnavailable, outputs: outputs)
    }
}

private final class SensorElementHandler: ResultElementHandler, LookupElementHandler {
    var results = [SensorInputDescriptor]()

    private let outputHandler = SensorOutputElementHandler()

    var childHandlers: [String : ElementHandler]

    init() {
        childHandlers = ["output": outputHandler]
    }

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case type
        case rate
        case rateStrategy
        case average
        case stride
        case ignoreUnavailable
        case nameFilter // ignored, only part of the file format for Android sensors
        case typeFilter // ignored, only part of the file format for Android sensors
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let sensor: SensorType = try attributes.value(for: .type)

        let frequency = try attributes.optionalValue(for: .rate) ?? 0.0
        //An invalid rate strategy is an error; only an absent attribute selects the
        //version-dependent default (enum-invalid-value in phyphox-docs, matching Android)
        let rateStrategy: ExperimentSensorInput.RateStrategy? = try attributes.optionalValue(for: .rateStrategy)
        let average = try attributes.optionalValue(for: .average) ?? false
        let stride = try attributes.optionalValue(for: .stride) ?? 1
        let ignoreUnavailable = try attributes.optionalValue(for: .ignoreUnavailable) ?? false

        let rate = frequency.isNormal ? 1.0/frequency : 0.0

        //Each output's component must be in the element's component list, once at most
        //(input-output-component-validation in phyphox-docs, matching Android)
        let outputs = try IOMappingValidation.validateComponents(element: "sensor", slots: sensorComponents, outputs: outputHandler.results)

        results.append(SensorInputDescriptor(sensor: sensor, rate: rate, rateStrategy: rateStrategy, average: average, stride: stride, ignoreUnavailable: ignoreUnavailable, outputs: outputs))
    }
}

struct AudioInputDescriptor: SensorDescriptor {
    let rate: UInt
    let outputs: [SensorOutputDescriptor]
    let appendData: Bool
}

private final class AudioElementHandler: ResultElementHandler, LookupElementHandler {
    var results = [AudioInputDescriptor]()

    private let outputHandler = SensorOutputElementHandler()

    var childHandlers: [String : ElementHandler]

    init() {
        childHandlers = ["output": outputHandler]
    }

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case rate
        case append
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let rate: UInt = try attributes.optionalValue(for: .rate) ?? 48000
        let appendData: Bool = try attributes.optionalValue(for: .append) ?? false

        //The recording output is required; an unnamed output fills it ("out")
        let outputs = try IOMappingValidation.validateComponents(element: "audio", slots: audioComponents, outputs: outputHandler.results)

        results.append(AudioInputDescriptor(rate: rate, outputs: outputs, appendData: appendData))
    }
}

enum BluetoothOutputExtra: String, CaseInsensitiveAttributeDecodable, CaseIterable {
    case time
    case none
}

struct BluetoothOutputDescriptor {
    let char: CBUUID
    let conversion: InputConversion?
    let bufferName: String
    let extra: BluetoothOutputExtra
}

private final class BluetoothOutputElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [BluetoothOutputDescriptor]()
    
    func startElement(attributes: AttributeContainer) throws {}
    
    private enum Attribute: String, AttributeKey {
        case char
        case extra
        case conversion
        case offset
        case repeating
        case stride
        case length
        case decimalPoint
        case separator
        case label
        case index
    }
    
    func endElement(text: String, attributes: AttributeContainer) throws {
        guard !text.isEmpty else { throw ElementHandlerError.missingText }
        
        let attributes = attributes.attributes(keyedBy: Attribute.self)
        
        let uuidString: String = try attributes.nonEmptyString(for: .char)
        let uuid = try CBUUID(uuidString: uuidString)
        
        let extra: BluetoothOutputExtra = try attributes.optionalValue(for: .extra) ?? .none
        
        let conversion: InputConversion?
        
        if extra == .none {
            let conversionName = try attributes.nonEmptyString(for: .conversion)
            
            switch conversionName.lowercased() { //Conversion function names are matched case-insensitively
            case "string":
                let decimalPoint: String? = attributes.optionalString(for: .decimalPoint)
                let offset: Int = try attributes.optionalValue(for: .offset) ?? 0
                let repeating: Int = try attributes.optionalValue(for: .repeating) ?? 0
                let length: Int? = try attributes.optionalValue(for: .length)
                conversion = StringInputConversion(decimalPoint: decimalPoint, offset: offset, repeating: repeating, length: length)
            case "formattedstring":
                let separator: String? = attributes.optionalString(for: .separator)
                let label: String? = attributes.optionalString(for: .label)
                let index: Int = try attributes.optionalValue(for: .index) ?? 0
                conversion = FormattedStringInputConversion(separator: separator, label: label, index: index)
            case "singlebyte":
                let offset: Int = try attributes.optionalValue(for: .offset) ?? 0
                let repeating: Int = try attributes.optionalValue(for: .repeating) ?? 0
                let length: Int? = try attributes.optionalValue(for: .length)
                conversion = SimpleInputConversion(function: .uInt8, offset: offset, repeating: repeating, length: length)
            default:
                let conversionFunction: SimpleInputConversion.ConversionFunction = try attributes.value(for: .conversion)
                let offset: Int = try attributes.optionalValue(for: .offset) ?? 0
                let repeating: Int = try attributes.optionalValue(for: .repeating) ?? 0
                let length: Int? = try attributes.optionalValue(for: .length)
                conversion = SimpleInputConversion(function: conversionFunction, offset: offset, repeating: repeating, length: length)
            }
        } else {
            conversion = nil
        }
        
        results.append(BluetoothOutputDescriptor(char: uuid, conversion: conversion, bufferName: text, extra: extra))
    }
    
    func clear() {
        results.removeAll()
    }
}

struct BluetoothConfigDescriptor {
    let char: CBUUID
    let data: Data
}

final class BluetoothConfigElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [BluetoothConfigDescriptor]()
    
    func startElement(attributes: AttributeContainer) throws {}
    
    private enum Attribute: String, AttributeKey {
        case char
        case conversion
    }
    
    func endElement(text: String, attributes: AttributeContainer) throws {
        guard !text.isEmpty else { throw ElementHandlerError.missingText }
        
        let attributes = attributes.attributes(keyedBy: Attribute.self)
        
        let uuidString: String = try attributes.nonEmptyString(for: .char)
        let uuid = try CBUUID(uuidString: uuidString)
        
        let conversionName = try attributes.nonEmptyString(for: .conversion)
        let conversion: ConfigConversion
        switch conversionName.lowercased() { //Conversion function names are matched case-insensitively
        case "singlebyte":
            conversion = SimpleConfigConversion(function: .uInt8)
        default:
            let conversionFunction: SimpleConfigConversion.ConversionFunction = try attributes.value(for: .conversion)
            conversion = SimpleConfigConversion(function: conversionFunction)
        }
        
        results.append(BluetoothConfigDescriptor(char: uuid, data: conversion.convert(data: text)))
    }
    
    func clear() {
        results.removeAll()
    }
}

enum BluetoothMode: String, CaseInsensitiveAttributeDecodable, CaseIterable {
    case notification
    case indication
    case poll
}

struct BluetoothInputBlockDescriptor {
    let id: String?
    let name: String?
    let uuid: CBUUID?
    let mode: BluetoothMode
    let rate: Double?
    let subscribeOnStart: Bool
    let autoConnect: Bool
    let outputs: [BluetoothOutputDescriptor]
    let configs: [BluetoothConfigDescriptor]
}

private final class BluetoothElementHandler: ResultElementHandler, LookupElementHandler {
    var results = [BluetoothInputBlockDescriptor]()
    
    private let outputHandler = BluetoothOutputElementHandler()
    private let configHandler = BluetoothConfigElementHandler()
    
    var childHandlers: [String : ElementHandler]
    
    init() {
        childHandlers = ["output": outputHandler, "config": configHandler]
    }
    
    func startElement(attributes: AttributeContainer) throws {}
    
    private enum Attribute: String, AttributeKey {
        case id
        case name
        case uuid
        case mode
        case subscribeOnStart
        case rate
        case autoConnect
        case mtu
    }
    
    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)
        
        let id: String? = attributes.optionalString(for: .id)
        let name: String? = attributes.optionalString(for: .name)
        let uuidString: String? = attributes.optionalString(for: .uuid)
        let uuid: CBUUID?
        if let uuidString = uuidString {
            uuid = try CBUUID(uuidString: uuidString)
        } else {
            uuid = nil
        }
        let mode: BluetoothMode = try attributes.value(for: .mode)
        let subscribeOnStart: Bool = try attributes.optionalValue(for: .subscribeOnStart) ?? false
        let autoConnect: Bool = try attributes.optionalValue(for: .autoConnect) ?? false
        let rate: Double? = try attributes.optionalValue(for: .rate)
        
        guard mode != .poll || (rate != nil && rate!.isFinite && rate! > 0) else {
            throw ElementHandlerError.message("For poll mode, a finite rate > 0 is required.")
        }
        
        results.append(BluetoothInputBlockDescriptor(id: id, name: name, uuid: uuid, mode: mode, rate: rate, subscribeOnStart: subscribeOnStart, autoConnect: autoConnect, outputs: outputHandler.results, configs: configHandler.results))
    }
}

final class InputElementHandler: ResultElementHandler, LookupElementHandler, AttributelessElementHandler {
    typealias Result = (sensors: [SensorInputDescriptor], depth: [DepthInputDescriptor], camera: [CameraInputDescriptor], audio: [AudioInputDescriptor], location: [LocationInputDescriptor], bluetooth: [BluetoothInputBlockDescriptor])

    var results = [Result]()

    private let sensorHandler = SensorElementHandler()
    private let depthHandler = DepthElementHandler()
    private let audioHandler = AudioElementHandler()
    private let locationHandler = LocationElementHandler()
    private let bluetoothHandler = BluetoothElementHandler()
    private let cameraHandler = CameraElementHandler()

    var childHandlers: [String: ElementHandler]

    init() {
        childHandlers = ["sensor": sensorHandler, "depth": depthHandler, "camera": cameraHandler, "audio": audioHandler, "location": locationHandler, "bluetooth": bluetoothHandler]
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let audio = audioHandler.results
        let location = locationHandler.results
        let sensors = sensorHandler.results
        let depth = depthHandler.results
        let camera = cameraHandler.results
        let bluetooth = bluetoothHandler.results

        results.append((sensors, depth, camera, audio, location, bluetooth))
    }
}


