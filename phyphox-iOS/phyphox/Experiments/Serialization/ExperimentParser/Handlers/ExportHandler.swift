//
//  ExportHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

struct ExportSetDataDescriptor {
    let name: String
    let bufferName: String
}

private final class ExportSetDataHandler: ResultElementHandler, ChildlessHandler {
    typealias Result = ExportSetDataDescriptor

    var results = [Result]()

    func beginElement(attributes: [String: String]) throws {
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        guard let name = attributes["name"], !name.isEmpty else {
            throw ParseError.missingAttribute("name")
        }

        guard !text.isEmpty else {
            throw ParseError.missingText
        }

        results.append(ExportSetDataDescriptor(name: name, bufferName: text))
    }
}

struct ExportSetDescriptor {
    let name: String

    let dataSets: [ExportSetDataDescriptor]
}

private final class ExportSetHandler: ResultElementHandler, LookupElementHandler {
    typealias Result = ExportSetDescriptor

    var results = [Result]()

    var handlers: [String : ElementHandler]

    private let dataHandler = ExportSetDataHandler()

    init() {
        handlers = ["data": dataHandler]
    }

    func beginElement(attributes: [String: String]) throws {
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        guard let name = attributes["name"], !name.isEmpty else {
            throw ParseError.missingAttribute("name")
        }

        results.append(ExportSetDescriptor(name: name, dataSets: dataHandler.results))
    }
}

final class ExportHandler: ResultElementHandler, LookupElementHandler, AttributelessHandler {
    typealias Result = [ExportSetDescriptor]

    var results = [Result]()

    var handlers: [String: ElementHandler]

    private let setHandler = ExportSetHandler()

    init() {
        handlers = ["set": setHandler]
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        results.append(setHandler.results)
    }
}
