//
//  DataContainersElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

// This file contains element handlers for the `data-container` child element (and its child elements) of the `phyphox` root element.

typealias BufferDescriptor = (name: String, size: Int, baseContents: [Double], staticBuffer: Bool)

private final class DataContainerElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [BufferDescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case size
        case staticKey = "static"
        case initKey = "init"
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        guard !text.isEmpty else { throw ElementHandlerError.missingText }

        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let size = try attributes.optionalValue(for: .size) ?? 1

        let baseContents = (attributes.optionalString(for: .initKey) as String?).map { $0.components(separatedBy: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) } } ?? []
        let staticBuffer = try attributes.optionalValue(for: .staticKey) ?? false

        results.append((text, size, baseContents, staticBuffer))
    }
}

final class DataContainersElementHandler: ResultElementHandler, LookupElementHandler, AttributelessElementHandler {
    var results = [[BufferDescriptor]]()

    var childHandlers: [String: ElementHandler]

    private let containerHandler = DataContainerElementHandler()

    init() {
        childHandlers = ["container": containerHandler]
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        results.append(containerHandler.results)
    }
}
