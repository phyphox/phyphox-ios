//
//  LinkHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class LinkHandler: ResultElementHandler, ChildlessHandler {
    typealias Result = (url: URL, label: String)

    var results = [Result]()

    func beginElement(attributes: [String: String]) throws {
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        guard !text.isEmpty else { throw ParseError.missingText }

        guard let label = attributes["label"], !label.isEmpty else { throw ParseError.missingAttribute("label") }

        guard let url = URL(string: label) else { throw ParseError.unreadableData }

        results.append((url, label))
    }
}
