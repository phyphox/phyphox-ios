//
//  SeparatorElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

// This file contains element handlers for the `separator` view element.

struct SeparatorViewElementDescriptor {
    let height: CGFloat
    let color: UIColor
}

final class SeparatorViewElementHandler: ResultElementHandler, ChildlessElementHandler, ViewComponentElementHandler {
    var results = [ViewElementDescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case height
        case color
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let height: CGFloat = try attributes.optionalValue(for: .height) ?? 0.1

        let color = mapColorString(attributes.optionalString(for: .color)) ?? kBackgroundColor

        results.append(.separator(SeparatorViewElementDescriptor(height: height, color: color)))
    }

    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}
