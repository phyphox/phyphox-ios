//
//  LinkElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

/// Element handler for the `link` child elements of the `phyphox` root element.
final class LinkElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [ExperimentLink]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case label
        case highlight
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        guard !text.isEmpty else { throw ElementHandlerError.missingText }

        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let label = attributes.optionalString(for: .label) ?? "default"

        guard let url = URL(string: text) else { throw ElementHandlerError.unexpectedAttributeValue("url") }

        let highlighted = try attributes.optionalValue(for: .highlight) ?? false

        results.append(ExperimentLink(label: label, url: url, highlighted: highlighted))
    }
}
