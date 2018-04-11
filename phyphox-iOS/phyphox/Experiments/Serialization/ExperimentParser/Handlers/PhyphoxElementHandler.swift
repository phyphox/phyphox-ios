//
//  PhyphoxElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class PhyphoxElementHandler: LookupResultElementHandler {
    typealias Result = Experiment

    private(set) var results = [Result]()

    let handlers: [String: ElementHandler]

    private let titleHandler = TextElementHandler()
    private let categoryHandler = TextElementHandler()
    private let descriptionHandler = TextElementHandler()
    private let iconHandler = IconHandler()
    private let linkHandler = LinkHandler()

    init() {
        handlers = ["title": titleHandler, "category": categoryHandler, "description": descriptionHandler, "icon": iconHandler, "link": linkHandler]
    }

    func beginElement(attributes: [String: String]) throws {
        guard attributes.isEmpty else {
            throw ParseError.unexpectedAttribute
        }
    }

    func endElement(with text: String) throws {

    }
}

extension PhyphoxElementHandler {
    func beginDocument() {
        results.removeAll()
    }
}
