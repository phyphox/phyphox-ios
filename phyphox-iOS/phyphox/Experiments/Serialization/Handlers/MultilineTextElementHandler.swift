//
//  MultilineTextElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

/// Element handler extracting multiline text content from an element. Text needs to be non-empty.
final class MultilineTextElementHandler: ResultElementHandler, AttributelessElementHandler, ChildlessElementHandler {
    var results = [String]()

    func endElement(text: String, attributes: AttributeContainer) throws {
        let cleanText = text.replacingOccurrences(of: "(?m)((?:^\\s+)|(?:\\s+$))", with: "\n", options: .regularExpression, range: nil)

        //guard !cleanText.isEmpty else { throw ElementHandlerError.missingText }

        results.append(cleanText)
    }
}
