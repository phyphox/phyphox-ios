//
//  ExportElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

// This file contains element handlers for the `export` child element (and its child elements) of the `phyphox` root element.

struct ExportSetDataDescriptor {
    let name: String
    let bufferName: String
}

private final class ExportSetDataElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [ExportSetDataDescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case name
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let name = try attributes.nonEmptyString(for: .name)

        guard !text.isEmpty else {
            throw ElementHandlerError.missingText
        }

        results.append(ExportSetDataDescriptor(name: name, bufferName: text))
    }
}

struct ExportSetDescriptor {
    let name: String

    let dataSets: [ExportSetDataDescriptor]
}

private final class ExportSetElementHandler: ResultElementHandler, LookupElementHandler {
    var results = [ExportSetDescriptor]()

    var childHandlers: [String: ElementHandler]

    private let dataHandler = ExportSetDataElementHandler()

    init() {
        childHandlers = ["data": dataHandler]
    }

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case name
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let name = try attributes.nonEmptyString(for: .name)

        results.append(ExportSetDescriptor(name: name, dataSets: dataHandler.results))
    }
}

final class ExportElementHandler: ResultElementHandler, LookupElementHandler, AttributelessElementHandler {
    var results = [[ExportSetDescriptor]]()

    var childHandlers: [String: ElementHandler]

    private let setHandler = ExportSetElementHandler()

    init() {
        childHandlers = ["set": setHandler]
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        results.append(setHandler.results)
    }
}
