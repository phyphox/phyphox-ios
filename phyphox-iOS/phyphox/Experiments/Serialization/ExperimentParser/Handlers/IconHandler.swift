//
//  IconHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class IconHandler: ResultElementHandler {
    typealias Result = ExperimentIcon

    private(set) var results = [Result]()

    private var format: String?

    func beginElement(attributes: [String: String]) throws {
        format = attributes["format"]
    }

    func childHandler(for tagName: String) throws -> ElementHandler {
        throw ParseError.unexpectedElement
    }

    func endElement(with text: String) throws {
        guard !text.isEmpty else { throw ParseError.missingText }

        if format == "base64" {
            guard let data = Data(base64Encoded: text, options: []) else { throw ParseError.unreadableData }

            let image = UIImage(data: data)

            results.append(ExperimentIcon(string: nil, image: image))
        }
        else if format == nil || format == "string" {
            results.append(ExperimentIcon(string: text, image: nil))
        }
        else {
            throw ParseError.unexpectedValue("format")
        }
    }
}
