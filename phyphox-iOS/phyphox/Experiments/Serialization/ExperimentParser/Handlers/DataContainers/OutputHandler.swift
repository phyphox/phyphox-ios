//
//  OutputHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

struct AudioOutputDescriptor {
    let rate: Int
    let loop: Bool

    let inputBufferNames: [String]
}

private final class AudioHandler: ResultElementHandler, LookupElementHandler {
    typealias Result = AudioOutputDescriptor

    var results = [Result]()

    private let inputHandler = TextElementHandler()

    var handlers: [String : ElementHandler]

    init() {
        handlers = ["input": inputHandler]
    }

    func beginElement(attributes: [String : String]) throws {
    }

    func childHandler(for tagName: String) throws -> ElementHandler {
        guard tagName == "input" else { throw ParseError.unexpectedElement }

        return inputHandler
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        let rate = attribute("rate", from: attributes, defaultValue: 48000)
        let loop = attribute("loop", from: attributes, defaultValue: false)

        results.append(AudioOutputDescriptor(rate: rate, loop: loop, inputBufferNames: inputHandler.results))
    }
}

final class OutputHandler: ResultElementHandler, LookupElementHandler, AttributelessHandler {
    typealias Result = [AudioOutputDescriptor]

    var results = [Result]()

    private let audioHandler = AudioHandler()

    var handlers: [String : ElementHandler]

    init() {
        handlers = ["audio": audioHandler]
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        results.append(audioHandler.results)
    }
}
