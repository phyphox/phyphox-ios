//
//  ExportElementHandler.swift
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

private final class ExportSetDataElementHandler: ResultElementHandler, ChildlessElementHandler {
    typealias Result = ExportSetDataDescriptor

    var results = [Result]()

    func beginElement(attributes: [String: String]) throws {
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        guard let name = attributes["name"], !name.isEmpty else {
            throw XMLElementParserError.missingAttribute("name")
        }

        guard !text.isEmpty else {
            throw XMLElementParserError.missingText
        }

        results.append(ExportSetDataDescriptor(name: name, bufferName: text))
    }
}

struct ExportSetDescriptor {
    let name: String

    let dataSets: [ExportSetDataDescriptor]
}

private final class ExportSetElementHandler: ResultElementHandler, LookupElementHandler {
    typealias Result = ExportSetDescriptor

    var results = [Result]()

    var handlers: [String : ElementHandler]

    private let dataHandler = ExportSetDataElementHandler()

    init() {
        handlers = ["data": dataHandler]
    }

    func beginElement(attributes: [String: String]) throws {
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        guard let name = attributes["name"], !name.isEmpty else {
            throw XMLElementParserError.missingAttribute("name")
        }

        results.append(ExportSetDescriptor(name: name, dataSets: dataHandler.results))
    }
}

final class ExportElementHandler: ResultElementHandler, LookupElementHandler, AttributelessElementHandler {
    typealias Result = [ExportSetDescriptor]

    var results = [Result]()

    var handlers: [String: ElementHandler]

    private let setHandler = ExportSetElementHandler()

    init() {
        handlers = ["set": setHandler]
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        results.append(setHandler.results)
    }
}
