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

    func beginElement(attributes: XMLElementAttributes) throws {
    }

    func endElement(with text: String, attributes: XMLElementAttributes) throws {
        let height: CGFloat = try attributes.attribute(for: "height") ?? 0.1
        let colorString: String? = try attributes.attribute(for: "color")

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
