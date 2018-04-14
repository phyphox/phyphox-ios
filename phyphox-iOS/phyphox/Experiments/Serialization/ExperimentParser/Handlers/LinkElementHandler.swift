//
//  LinkElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class LinkElementHandler: ResultElementHandler, ChildlessElementHandler {
    typealias Result = ExperimentLink

    var results = [Result]()

    func beginElement(attributes: [String: String]) throws {
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        guard !text.isEmpty else { throw XMLElementParserError.missingText }

        guard let label = attributes["label"], !label.isEmpty else { throw XMLElementParserError.missingAttribute("label") }

        guard let url = URL(string: text) else { throw XMLElementParserError.unexpectedValue("url") }

        let highlighted = attribute("highlight", from: attributes, defaultValue: false)

        results.append(ExperimentLink(label: label, url: url, highlighted: highlighted))
    }
}
