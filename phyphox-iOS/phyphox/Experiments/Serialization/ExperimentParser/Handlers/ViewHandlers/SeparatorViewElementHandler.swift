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
    typealias Result = SeparatorViewElementDescriptor

    var results = [Result]()

    func beginElement(attributeContainer: XMLElementAttributeContainer) throws {}

    // Bug in Swift 4.1 compiler (https://bugs.swift.org/browse/SR-7153). Make private again when compiling with Swift 4.2
    /*private*/ enum Attribute: String, XMLAttributeKey {
        case height
        case color
    }

    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws {
        let attributes = attributeContainer.attributes(keyedBy: Attribute.self)

        let height: CGFloat = try attributes.optionalAttribute(for: .height) ?? 0.1
        let colorString: String? = try attributes.optionalAttribute(for: .color)

        let color = try colorString.map({ string -> UIColor in
            guard let color = UIColor(hexString: string) else {
                throw XMLElementParserError.unexpectedAttributeValue("color")
            }

            return color
        }) ?? kBackgroundColor

        results.append(SeparatorViewElementDescriptor(height: height, color: color))
    }

    func getResult() throws -> ViewElementDescriptor {
        return try expectSingleResult()
    }
}
