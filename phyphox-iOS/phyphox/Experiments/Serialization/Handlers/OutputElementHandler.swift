//
//  OutputElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreBluetooth

// This file contains element handlers for the `output` child element (and its child elements) of the `phyphox` root element.

enum AudioOutputSubInputDescriptor {
    case value(value: Double, usedAs: String)
    case buffer(name: String, usedAs: String)
}

final class AudioOutputSubInputElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [AudioOutputSubInputDescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case type
        case clear
        case usedAs = "parameter"
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let type = try attributes.optionalValue(for: .type) ?? DataInputTypeAttribute.buffer
        let usedAs = attributes.optionalString(for: .usedAs) ?? ""

        switch type {
        case .buffer:
            guard !text.isEmpty else { throw ElementHandlerError.missingText }

            results.append(.buffer(name: text, usedAs: usedAs))
        case .value:
            guard !text.isEmpty else { throw ElementHandlerError.missingText }

            guard let value = Double(text) else {
                throw ElementHandlerError.unreadableData
            }

            results.append(.value(value: value, usedAs: usedAs))
        case .empty:
            break
        }
    }
}

struct AudioOutputToneDescriptor {
    let inputs: [AudioOutputSubInputDescriptor]
}

private final class AudioToneElementHandler: ResultElementHandler, LookupElementHandler {
    var results = [AudioOutputToneDescriptor]()
    
    private let inputsHandler = AudioOutputSubInputElementHandler()
    
    var childHandlers: [String : ElementHandler]
    
    init() {
        childHandlers = ["input": inputsHandler]
    }
    
    func startElement(attributes: AttributeContainer) throws {}
    
    func endElement(text: String, attributes: AttributeContainer) throws {
        let inputs = inputsHandler.results
        
        results.append(AudioOutputToneDescriptor(inputs: inputs))
    }
}

struct AudioOutputNoiseDescriptor {
    let inputs: [AudioOutputSubInputDescriptor]
}

private final class AudioNoiseElementHandler: ResultElementHandler, LookupElementHandler {
    var results = [AudioOutputNoiseDescriptor]()
    
    private let inputsHandler = AudioOutputSubInputElementHandler()
    
    var childHandlers: [String : ElementHandler]
    
    init() {
        childHandlers = ["input": inputsHandler]
    }
    
    func startElement(attributes: AttributeContainer) throws {}
    
    func endElement(text: String, attributes: AttributeContainer) throws {
        let inputs = inputsHandler.results
        
        results.append(AudioOutputNoiseDescriptor(inputs: inputs))
    }
}

struct AudioOutputDescriptor {
    let rate: UInt
    let loop: Bool
    let normalize: Bool

    let inputBufferName: String?
    let tones: [AudioOutputToneDescriptor]
    let noise: AudioOutputNoiseDescriptor?
}

private final class AudioElementHandler: ResultElementHandler, LookupElementHandler {
    var results = [AudioOutputDescriptor]()

    private let inputHandler = TextElementHandler()
    private let toneHandler = AudioToneElementHandler()
    private let noiseHandler = AudioNoiseElementHandler()

    var childHandlers: [String : ElementHandler]

    init() {
        childHandlers = ["input": inputHandler, "tone": toneHandler, "noise": noiseHandler]
    }

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case rate
        case loop
        case normalize
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let rate: UInt = try attributes.optionalValue(for: .rate) ?? 48000
        let loop = try attributes.optionalValue(for: .loop) ?? false
        let normalize = try attributes.optionalValue(for: .normalize) ?? false

        let inputBufferName = try inputHandler.expectOptionalResult()
        let tones = toneHandler.results
        let noise = try noiseHandler.expectOptionalResult()
        
        results.append(AudioOutputDescriptor(rate: rate, loop: loop, normalize: normalize, inputBufferName: inputBufferName, tones: tones, noise: noise))
    }
}

struct BluetoothInputDescriptor {
    let char: CBUUID
    let conversion: OutputConversion?
    let bufferName: String
}

private final class BluetoothInputElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [BluetoothInputDescriptor]()
    
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
        
        let conversion: OutputConversion?
        let conversionName = try attributes.nonEmptyString(for: .conversion)
        
        switch conversionName {
        case "byteArray":
            conversion = ByteArrayOutputConversion()
        case "singleByte":
            conversion = SimpleOutputConversion(function: .uInt8)
        default:
            let conversionFunction: SimpleOutputConversion.ConversionFunction = try attributes.value(for: .conversion)
            conversion = SimpleOutputConversion(function: conversionFunction)
        }
        
        results.append(BluetoothInputDescriptor(char: uuid, conversion: conversion, bufferName: text))
    }
    
    func clear() {
        results.removeAll()
    }
}

struct BluetoothOutputBlockDescriptor {
    let id: String?
    let name: String?
    let uuid: CBUUID?
    let autoConnect: Bool
    let inputs: [BluetoothInputDescriptor]
    let configs: [BluetoothConfigDescriptor]
}

private final class BluetoothElementHandler: ResultElementHandler, LookupElementHandler {
    var results = [BluetoothOutputBlockDescriptor]()
    
    private let inputHandler = BluetoothInputElementHandler()
    private let configHandler = BluetoothConfigElementHandler() //Reused from InputElementHandler.swift
    
    var childHandlers: [String : ElementHandler]
    
    init() {
        childHandlers = ["input": inputHandler, "config": configHandler]
    }
    
    func startElement(attributes: AttributeContainer) throws {}
    
    private enum Attribute: String, AttributeKey {
        case id
        case name
        case uuid
        case autoConnect
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
        
        let autoConnect: Bool = try attributes.optionalValue(for: .autoConnect) ?? false
        
        results.append(BluetoothOutputBlockDescriptor(id: id, name: name, uuid: uuid, autoConnect: autoConnect, inputs: inputHandler.results, configs: configHandler.results))
    }
}

struct OutputDescriptor {
    let audioOutput: AudioOutputDescriptor?
    let bluetooth: [BluetoothOutputBlockDescriptor]
}

final class OutputElementHandler: ResultElementHandler, LookupElementHandler, AttributelessElementHandler {
    typealias Result = OutputDescriptor

    var results = [Result]()

    private let audioHandler = AudioElementHandler()
    private let bluetoothHandler = BluetoothElementHandler()

    var childHandlers: [String : ElementHandler]

    init() {
        childHandlers = ["audio": audioHandler, "bluetooth": bluetoothHandler]
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        results.append(OutputDescriptor(audioOutput: try audioHandler.expectOptionalResult(), bluetooth: bluetoothHandler.results))
    }
}
