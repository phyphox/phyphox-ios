//
//  OutputElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

struct AudioOutputDescriptor {
    let rate: UInt
    let loop: Bool

    let inputBufferName: String
}

private final class AudioElementHandler: ResultElementHandler, LookupElementHandler {
    typealias Result = AudioOutputDescriptor

    var results = [Result]()

    private let inputHandler = TextElementHandler()

    var handlers: [String : ElementHandler]

    init() {
        handlers = ["input": inputHandler]
    }

    func beginElement(attributes: [String: String]) throws {
    }

    func childHandler(for tagName: String) throws -> ElementHandler {
        guard tagName == "input" else { throw XMLElementParserError.unexpectedChildElement(tagName) }

        return inputHandler
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        let rate: UInt = attribute("rate", from: attributes, defaultValue: 48000)
        let loop = attribute("loop", from: attributes, defaultValue: false)

        let inputBufferName = try inputHandler.expectSingleResult()
        
        results.append(AudioOutputDescriptor(rate: rate, loop: loop, inputBufferName: inputBufferName))
    }
}

final class OutputElementHandler: ResultElementHandler, LookupElementHandler, AttributelessHandler {
    typealias Result = AudioOutputDescriptor

    var results = [Result]()

    private let audioHandler = AudioElementHandler()

    var handlers: [String : ElementHandler]

    init() {
        handlers = ["audio": audioHandler]
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        results.append(try audioHandler.expectSingleResult())
    }
}
