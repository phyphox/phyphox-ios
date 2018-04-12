//
//  InputHandler.swift
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

private final class SensorOutputHandler: ResultElementHandler, ChildlessHandler {
    typealias Result = SensorOutputDescriptor

    var results = [Result]()

    func beginElement(attributes: [String : String]) throws {
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        guard !text.isEmpty else { throw ParseError.missingText }

        let component = attributes["components"]
        results.append(SensorOutputDescriptor(component: component, bufferName: text))
    }

    func clear() {
        results.removeAll()
    }
}

struct LocationInputDescriptor: SensorDescriptor {
    let outputs: [SensorOutputDescriptor]
}

private final class LocationHandler: ResultElementHandler, LookupElementHandler {
    typealias Result = LocationInputDescriptor

    var results = [Result]()

    private let outputHandler = SensorOutputHandler()

    var handlers: [String : ElementHandler]

    init() {
        handlers = ["output": outputHandler]
    }

    func beginElement(attributes: [String : String]) throws {
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

private final class SensorHandler: ResultElementHandler, LookupElementHandler {
    typealias Result = SensorInputDescriptor

    var results = [Result]()

    private let outputHandler = SensorOutputHandler()

    var handlers: [String : ElementHandler]

    init() {
        handlers = ["output": outputHandler]
    }

    func beginElement(attributes: [String : String]) throws {
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        guard let sensor: SensorType = attribute("type", from: attributes) else { throw ParseError.unreadableData }

        let rate = attribute("rate", from: attributes, defaultValue: 0.0)
        let average = attribute("average", from: attributes, defaultValue: false)

        results.append(SensorInputDescriptor(sensor: sensor, rate: rate, average: average, outputs: outputHandler.results))
    }
}

struct AudioInputDescriptor: SensorDescriptor {
    let rate: UInt
    let outputs: [SensorOutputDescriptor]
}

private final class AudioHandler: ResultElementHandler, LookupElementHandler {
    typealias Result = AudioInputDescriptor

    var results = [Result]()

    private let outputHandler = SensorOutputHandler()

    var handlers: [String : ElementHandler]

    init() {
        handlers = ["output": outputHandler]
    }

    func beginElement(attributes: [String : String]) throws {
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        let rate: UInt = attribute("rate", from: attributes, defaultValue: 48000)
        results.append(AudioInputDescriptor(rate: rate, outputs: outputHandler.results))
    }
}

final class InputHandler: ResultElementHandler, LookupElementHandler, AttributelessHandler {
    typealias Result = (sensors: [SensorInputDescriptor], audio: AudioInputDescriptor?, location: LocationInputDescriptor?)

    var results = [Result]()

    private let sensorHandler = SensorHandler()
    private let audioHandler = AudioHandler()
    private let locationHandler = LocationHandler()

    var handlers: [String: ElementHandler]

    init() {
        handlers = ["sensor": sensorHandler, "audio": audioHandler, "location": locationHandler]
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        let audio = try audioHandler.expectOptionalResult()
        let location = try locationHandler.expectOptionalResult()

        let sensors = sensorHandler.results

        results.append((sensors, audio, location))
    }
}
