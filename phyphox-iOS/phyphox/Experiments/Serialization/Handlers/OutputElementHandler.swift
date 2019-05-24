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

struct AudioOutputDescriptor {
    let rate: UInt
    let loop: Bool

    let inputBufferName: String
}

private final class AudioElementHandler: ResultElementHandler, LookupElementHandler {
    var results = [AudioOutputDescriptor]()

    private let inputHandler = TextElementHandler()

    var childHandlers: [String : ElementHandler]

    init() {
        childHandlers = ["input": inputHandler]
    }

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case rate
        case loop
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let rate: UInt = try attributes.optionalValue(for: .rate) ?? 48000
        let loop = try attributes.optionalValue(for: .loop) ?? false

        let inputBufferName = try inputHandler.expectSingleResult()
        
        results.append(AudioOutputDescriptor(rate: rate, loop: loop, inputBufferName: inputBufferName))
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
        
        results.append(BluetoothOutputBlockDescriptor(id: id, name: name, uuid: uuid, inputs: inputHandler.results, configs: configHandler.results))
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
