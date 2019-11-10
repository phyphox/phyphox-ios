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
    let color: UIColor
    let fontSize: CGFloat
    let align: TextAlignment
    let bold: Bool
    let italic: Bool
    
    enum TextAlignment: String, LosslessStringConvertible {
        case left, right, center
    }
}

final class InfoViewElementHandler: ResultElementHandler, ChildlessElementHandler, ViewComponentElementHandler {
    var results = [ViewElementDescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case label
        case color
        case size
        case align
        case bold
        case italic
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let label = attributes.optionalString(for: .label) ?? ""
        let color = mapColorString(attributes.optionalString(for: .color)) ?? kTextColor
        let fontSize = CGFloat(try attributes.optionalValue(for: .size) ?? 1.0)
        let align: InfoViewElementDescriptor.TextAlignment = try attributes.optionalValue(for: .align) ?? .left
        let bold = try attributes.optionalValue(for: .bold) ?? false
        let italic = try attributes.optionalValue(for: .italic) ?? false

        results.append(.info(InfoViewElementDescriptor(label: label, color: color, fontSize: fontSize, align: align, bold: bold, italic: italic)))
    }

    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}
