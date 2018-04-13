//
//  SeparatorHandler.swift
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

final class SeparatorViewHandler: ResultElementHandler, ChildlessHandler, ViewComponentHandler {
    typealias Result = SeparatorViewElementDescriptor

    var results = [Result]()

    func beginElement(attributes: [String: String]) throws {
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        let height: CGFloat = attribute("height", from: attributes, defaultValue: 0.1)
        let colorString: String? = attribute("color", from: attributes)

        let color = try colorString.map({ string -> UIColor in
            guard let color = UIColor(hexString: string) else {
                throw ParseError.unexpectedValue("color")
            }

            return color
        }) ?? kBackgroundColor

        results.append(SeparatorViewElementDescriptor(height: height, color: color))
    }

    func getResult() throws -> ViewElementDescriptor {
        return try expectSingleResult()
    }
}
