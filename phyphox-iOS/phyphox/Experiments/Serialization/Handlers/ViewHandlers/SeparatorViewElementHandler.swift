//
//  SeparatorElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

struct SeparatorViewElementDescriptor: ViewElementDescriptor {
    let height: CGFloat
    let color: UIColor
}

final class SeparatorViewElementHandler: ResultElementHandler, ChildlessElementHandler, ViewComponentElementHandler {
    var results = [SeparatorViewElementDescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case height
        case color
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let height: CGFloat = try attributes.optionalValue(for: .height) ?? 0.1
        let colorString: String? = attributes.optionalString(for: .color)

        let color = try colorString.map({ string -> UIColor in
            guard let color = UIColor(hexString: string) else {
                throw ElementHandlerError.unexpectedAttributeValue("color")
            }

            return color
        }) ?? kBackgroundColor

        results.append(SeparatorViewElementDescriptor(height: height, color: color))
    }

    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}
