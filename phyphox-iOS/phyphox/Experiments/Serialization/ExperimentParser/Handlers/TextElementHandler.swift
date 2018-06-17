//
//  TextElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class TextElementHandler: ResultElementHandler, AttributelessElementHandler, ChildlessElementHandler {
    typealias Result = String

    var results = [Result]()

    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws {
        guard !text.isEmpty else { throw XMLElementParserError.missingText }

        results.append(text)
    }
}
