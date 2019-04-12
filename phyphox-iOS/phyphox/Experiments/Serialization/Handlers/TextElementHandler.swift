//
//  TextElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

/// Element handler extracting the text content from an element. Text needs to be non-empty.
final class TextElementHandler: ResultElementHandler, AttributelessElementHandler, ChildlessElementHandler {
    var results = [String]()

    func endElement(text: String, attributes: AttributeContainer) throws {
        guard !text.isEmpty else { throw ElementHandlerError.missingText }

        results.append(text)
    }
}
