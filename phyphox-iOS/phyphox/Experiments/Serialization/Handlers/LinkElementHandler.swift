//
//  LinkElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

/// Handler for the root's link children. The label is required, a translated link is matched on it; the translation
/// attribute and an empty URL are only valid inside a translation block (translation-link-matching in phyphox-docs)
final class LinkElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [ExperimentLink]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case label
        case highlight
        case translation
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        guard !text.isEmpty else { throw ElementHandlerError.missingText }

        let attributes = attributes.attributes(keyedBy: Attribute.self)

        guard attributes.optionalString(for: .translation) == nil else {
            throw ElementHandlerError.unexpectedAttribute("translation")
        }

        let label = try attributes.string(for: .label)

        guard let url = URL(string: text) else { throw ElementHandlerError.unexpectedAttributeValue("url") }

        let highlighted = try attributes.optionalValue(for: .highlight) ?? false

        results.append(ExperimentLink(label: label, url: url, highlighted: highlighted))
    }
}
