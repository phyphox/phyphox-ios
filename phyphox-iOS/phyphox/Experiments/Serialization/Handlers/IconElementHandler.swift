//
//  IconElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

/// Element handler for the `icon` child element of the `phyphox` root element.
final class IconElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [ExperimentIcon]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case format
    }

    private enum Format: String, LosslessStringConvertible {
        case base64
        case string
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        guard !text.isEmpty else { throw ElementHandlerError.missingText }

        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let format: Format = try attributes.optionalValue(for: .format) ?? .string

        switch format {
        case .base64:
            guard let data = Data(base64Encoded: text, options: []) else { throw ElementHandlerError.unreadableData }

            if let image = UIImage(data: data) {
                results.append(.image(image))
            }
        case .string:
            results.append(.string(text))
        }
    }
}
