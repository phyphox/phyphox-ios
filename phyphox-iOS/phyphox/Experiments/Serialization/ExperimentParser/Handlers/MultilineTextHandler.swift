//
//  MultilineTextElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class MultilineTextElementHandler: ResultElementHandler, AttributelessHandler, ChildlessHandler {
    typealias Result = String

    var results = [Result]()

    func endElement(with text: String, attributes: [String: String]) throws {
        let cleanText = text.replacingOccurrences(of: "(?m)((?:^\\s+)|(?:\\s+$))", with: "\n", options: .regularExpression, range: nil)

        guard !cleanText.isEmpty else { throw XMLElementParserError.missingText }

        results.append(cleanText)
    }
}
