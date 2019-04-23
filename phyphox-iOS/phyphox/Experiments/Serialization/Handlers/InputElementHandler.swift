//
//  InputElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

// This file contains element handlers for the `input` child element (and its child elements) of the `phyphox` root element.

struct SensorOutputDescriptor {
    let component: String?
    let bufferName: String
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

        let component = attributes.optionalString(for: .component) ?? "output"
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
        results.append(LocationInputDescriptor(outputs: outputHandler.results))
    }
}

struct SensorInputDescriptor: SensorDescriptor {
    let sensor: SensorType
    let rate: Double
    let average: Bool

    let outputs: [SensorOutputDescriptor]
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
        case average
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let sensor: SensorType = try attributes.value(for: .type)

        let frequency = try attributes.optionalValue(for: .rate) ?? 0.0
        let average = try attributes.optionalValue(for: .average) ?? false

        let rate = frequency.isNormal ? 1.0/frequency : 0.0

        if average && rate == 0.0 {
            throw ElementHandlerError.message("Averaging is enabled but rate is 0")
        }

        results.append(SensorInputDescriptor(sensor: sensor, rate: rate, average: average, outputs: outputHandler.results))
    }
}

struct AudioInputDescriptor: SensorDescriptor {
    let rate: UInt
    let outputs: [SensorOutputDescriptor]
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
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let rate: UInt = try attributes.optionalValue(for: .rate) ?? 48000

        results.append(AudioInputDescriptor(rate: rate, outputs: outputHandler.results))
    }
}

final class InputElementHandler: ResultElementHandler, LookupElementHandler, AttributelessElementHandler {
    typealias Result = (sensors: [SensorInputDescriptor], audio: [AudioInputDescriptor], location: [LocationInputDescriptor])

    var results = [Result]()

    private let sensorHandler = SensorElementHandler()
    private let audioHandler = AudioElementHandler()
    private let locationHandler = LocationElementHandler()

    var childHandlers: [String: ElementHandler]

    init() {
        childHandlers = ["sensor": sensorHandler, "audio": audioHandler, "location": locationHandler]
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let audio = audioHandler.results
        let location = locationHandler.results
        let sensors = sensorHandler.results

        results.append((sensors, audio, location))
    }
}
