//
//  LinkHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class LinkHandler: ResultElementHandler {
    typealias Result = (url: URL, label: String)

    private(set) var results = [Result]()

    private var label: String?

    func beginElement(attributes: [String: String]) throws {
        label = attributes["label"]
    }

    func childHandler(for tagName: String) throws -> ElementHandler {
        throw ParseError.unexpectedElement
    }

    func endElement(with text: String) throws {
        guard !text.isEmpty else { throw ParseError.missingText }

        guard let label = label, !label.isEmpty else { throw ParseError.missingAttribute("label") }

        guard let url = URL(string: label) else { throw ParseError.unreadableData }

        results.append((url, label))
    }
}
