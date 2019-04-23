//
//  OutputElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

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

struct OutputDescriptor {
    let audioOutput: AudioOutputDescriptor?
}

final class OutputElementHandler: ResultElementHandler, LookupElementHandler, AttributelessElementHandler {
    typealias Result = OutputDescriptor

    var results = [Result]()

    private let audioHandler = AudioElementHandler()

    var childHandlers: [String : ElementHandler]

    init() {
        childHandlers = ["audio": audioHandler]
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        results.append(OutputDescriptor(audioOutput: try audioHandler.expectOptionalResult()))
    }
}
