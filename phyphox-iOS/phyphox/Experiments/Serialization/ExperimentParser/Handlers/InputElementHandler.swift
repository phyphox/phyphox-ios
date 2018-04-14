//
//  InputElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

struct SensorOutputDescriptor {
    let component: String?
    let bufferName: String
}

protocol SensorDescriptor {
    var outputs: [SensorOutputDescriptor] { get }
}

private final class SensorOutputElementHandler: ResultElementHandler, ChildlessElementHandler {
    typealias Result = SensorOutputDescriptor

    var results = [Result]()

    func beginElement(attributes: [String: String]) throws {
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        guard !text.isEmpty else { throw XMLElementParserError.missingText }

        let component = attributes["component"] ?? "output"
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
    typealias Result = LocationInputDescriptor

    var results = [Result]()

    private let outputHandler = SensorOutputElementHandler()

    var handlers: [String : ElementHandler]

    init() {
        handlers = ["output": outputHandler]
    }

    func beginElement(attributes: [String: String]) throws {
    }

    func endElement(with text: String, attributes: [String: String]) throws {
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
    typealias Result = SensorInputDescriptor

    var results = [Result]()

    private let outputHandler = SensorOutputElementHandler()

    var handlers: [String : ElementHandler]

    init() {
        handlers = ["output": outputHandler]
    }

    func beginElement(attributes: [String: String]) throws {
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        guard let sensor: SensorType = try attribute("type", from: attributes) else { throw XMLElementParserError.unexpectedAttributeValue("type") }

        let frequency = try attribute("rate", from: attributes, defaultValue: 0.0)
        let average = try attribute("average", from: attributes, defaultValue: false)

        let rate = frequency.isNormal ? 1.0/frequency : 0.0

        results.append(SensorInputDescriptor(sensor: sensor, rate: rate, average: average, outputs: outputHandler.results))
    }
}

struct AudioInputDescriptor: SensorDescriptor {
    let rate: UInt
    let outputs: [SensorOutputDescriptor]
}

private final class AudioElementHandler: ResultElementHandler, LookupElementHandler {
    typealias Result = AudioInputDescriptor

    var results = [Result]()

    private let outputHandler = SensorOutputElementHandler()

    var handlers: [String : ElementHandler]

    init() {
        handlers = ["output": outputHandler]
    }

    func beginElement(attributes: [String: String]) throws {
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        let rate: UInt = try attribute("rate", from: attributes, defaultValue: 48000)
        results.append(AudioInputDescriptor(rate: rate, outputs: outputHandler.results))
    }
}

final class InputElementHandler: ResultElementHandler, LookupElementHandler, AttributelessElementHandler {
    typealias Result = (sensors: [SensorInputDescriptor], audio: [AudioInputDescriptor], location: [LocationInputDescriptor])

    var results = [Result]()

    private let sensorHandler = SensorElementHandler()
    private let audioHandler = AudioElementHandler()
    private let locationHandler = LocationElementHandler()

    var handlers: [String: ElementHandler]

    init() {
        handlers = ["sensor": sensorHandler, "audio": audioHandler, "location": locationHandler]
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        let audio = audioHandler.results
        let location = locationHandler.results
        let sensors = sensorHandler.results

        results.append((sensors, audio, location))
    }
}
