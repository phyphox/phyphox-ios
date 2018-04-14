//
//  TextElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class TextElementHandler: ResultElementHandler, AttributelessHandler, ChildlessHandler {
    typealias Result = String

    var results = [Result]()

    func endElement(with text: String, attributes: [String: String]) throws {
        guard !text.isEmpty else { throw XMLElementParserError.missingText }

        results.append(text)
    }
}
