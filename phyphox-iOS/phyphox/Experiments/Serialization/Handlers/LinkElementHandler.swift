//
//  LinkElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

/// Element handler for the `link` child elements of the `phyphox` root element. The label is
/// required and acts as the key a translated link is matched on; the translation attribute and an
/// empty URL are only meaningful on a link inside a translation block (see
/// `TranslatedLinkElementHandler`) and are errors here (translation-link-matching in phyphox-docs).
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
