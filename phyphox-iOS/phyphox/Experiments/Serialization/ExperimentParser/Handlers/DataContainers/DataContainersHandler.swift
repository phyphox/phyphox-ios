//
//  DataContainersHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

typealias BufferDescriptor = (name: String, size: Int, baseContents: [Double], staticBuffer: Bool)

private final class DataContainerHandler: ChildLessResultHandler {
    typealias Result = BufferDescriptor

    private(set) var results = [Result]()

    private var size = 1
    private var baseContents = [Double]()
    private var staticBuffer = false

    func beginElement(attributes: [String : String]) throws {
        size = attribute("size", from: attributes, defaultValue: 1)
        baseContents = attributes["init"].map { $0.components(separatedBy: ",").compactMap{ Double($0.trimmingCharacters(in: .whitespaces))} } ?? []
        staticBuffer = attribute("static", from: attributes, defaultValue: false)
    }

    func endElement(with text: String) throws {
        guard !text.isEmpty else { throw ParseError.missingText }

        results.append((text, size, baseContents, staticBuffer))
    }
}

final class DataContainersHandler: AttributeLessResultHandler {
    typealias Result = [BufferDescriptor]

    private(set) var results = [Result]()

    private let containerHandler = DataContainerHandler()

    func childHandler(for tagName: String) throws -> ElementHandler {
        guard tagName == "container" else {
            throw ParseError.unexpectedElement
        }

        return containerHandler
    }

    func endElement(with text: String) throws {
        guard text.isEmpty else { throw ParseError.unexpectedText }

        results.append(containerHandler.results)
    }
}
