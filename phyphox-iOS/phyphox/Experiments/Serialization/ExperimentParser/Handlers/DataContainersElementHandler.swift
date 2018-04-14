//
//  DataContainersElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

typealias BufferDescriptor = (name: String, size: Int, baseContents: [Double], staticBuffer: Bool)

private final class DataContainerElementHandler: ResultElementHandler, ChildlessElementHandler {
    typealias Result = BufferDescriptor

    var results = [Result]()

    func beginElement(attributes: [String: String]) throws {
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        guard !text.isEmpty else { throw XMLElementParserError.missingText }

        let size = try attribute("size", from: attributes, defaultValue: 1)
        let baseContents = attributes["init"].map { $0.components(separatedBy: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) } } ?? []
        let staticBuffer = try attribute("static", from: attributes, defaultValue: false)

        results.append((text, size, baseContents, staticBuffer))
    }
}

final class DataContainersElementHandler: ResultElementHandler, LookupElementHandler, AttributelessElementHandler {
    typealias Result = [BufferDescriptor]

    var handlers: [String: ElementHandler]

    var results = [Result]()

    private let containerHandler = DataContainerElementHandler()

    init() {
        handlers = ["container": containerHandler]
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        results.append(containerHandler.results)
    }
}
