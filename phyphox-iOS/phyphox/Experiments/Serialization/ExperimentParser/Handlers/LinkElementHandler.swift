//
//  LinkElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class LinkElementHandler: ResultElementHandler, ChildlessElementHandler {
    typealias Result = ExperimentLink

    var results = [Result]()

    func beginElement(attributeContainer: XMLElementAttributeContainer) throws {}

    // Bug in Swift 4.1 compiler (https://bugs.swift.org/browse/SR-7153). Make private again when compiling with Swift 4.2
    /*private*/ enum Attribute: String, XMLAttributeKey {
        case label
        case highlight
    }

    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws {
        guard !text.isEmpty else { throw XMLElementParserError.missingText }

        let attributes = attributeContainer.attributes(keyedBy: Attribute.self)

        let label = try attributes.nonEmptyString(for: .label)

        guard let url = URL(string: text) else { throw XMLElementParserError.unexpectedAttributeValue("url") }

        let highlighted = try attributes.optionalAttribute(for: .highlight) ?? false

        results.append(ExperimentLink(label: label, url: url, highlighted: highlighted))
    }
}
