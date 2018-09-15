//
//  InfoViewElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

// This file contains element handlers for the `info` view element.

struct InfoViewElementDescriptor {
    let label: String
}

final class InfoViewElementHandler: ResultElementHandler, ChildlessElementHandler, ViewComponentElementHandler {
    var results = [ViewElementDescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case label
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let label = try attributes.nonEmptyString(for: .label)

        results.append(.info(InfoViewElementDescriptor(label: label)))
    }

    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}
