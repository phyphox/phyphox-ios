//
//  DataContainersElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

// This file contains element handlers for the `data-container` child element (and its child elements) of the `phyphox` root element.

typealias BufferDescriptor = (name: String, size: Int, baseContents: [Double], staticBuffer: Bool, clearGroup: String?)

private final class DataContainerElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [BufferDescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case size
        case staticKey = "static"
        case initKey = "init"
        case clearGroup
        case type
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        guard !text.isEmpty else { throw ElementHandlerError.missingText }

        let attributes = attributes.attributes(keyedBy: Attribute.self)

        //Only "buffer" exists; the attribute is reserved for future container types, so an
        //unknown value must not silently load as an ordinary buffer
        //(container-type-unvalidated in phyphox-docs, matching Android)
        if let type = attributes.optionalString(for: .type), type.lowercased() != "buffer" {
            throw ElementHandlerError.message("Unknown container type \"\(type)\".")
        }

        let size = try attributes.optionalValue(for: .size) ?? 1

        //A malformed init entry rejects the file instead of being silently dropped, which would
        //also shift every later entry one position forward (number-invalid-value rule in
        //phyphox-docs). An empty attribute still just starts the buffer empty, but an empty
        //entry ("1,,2", a trailing comma) is an error.
        let baseContents: [Double]
        if let initValues = attributes.optionalString(for: .initKey), !initValues.isEmpty {
            baseContents = try initValues.components(separatedBy: ",").map {
                guard let value = parseExperimentNumber($0.trimmingCharacters(in: .whitespaces)) else {
                    throw ElementHandlerError.unexpectedAttributeValue("init")
                }
                return value
            }
        } else {
            baseContents = []
        }
        let staticBuffer = try attributes.optionalValue(for: .staticKey) ?? false

        let clearGroup = attributes.optionalString(for: .clearGroup)

        results.append((text, size, baseContents, staticBuffer, clearGroup))
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
