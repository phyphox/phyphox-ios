//
//  LinkHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class LinkHandler: ResultElementHandler, ChildlessHandler {
    typealias Result = ExperimentLink

    var results = [Result]()

    func beginElement(attributes: [String: String]) throws {
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        guard !text.isEmpty else { throw ParseError.missingText }

        guard let label = attributes["label"], !label.isEmpty else { throw ParseError.missingAttribute("label") }

        guard let url = URL(string: text) else { throw ParseError.unreadableData }

        let highlighted = attribute("highlight", from: attributes, defaultValue: false)

        results.append(ExperimentLink(label: label, url: url, highlighted: highlighted))
    }
}
