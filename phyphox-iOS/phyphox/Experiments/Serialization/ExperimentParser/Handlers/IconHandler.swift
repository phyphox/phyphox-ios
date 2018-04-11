//
//  IconHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class IconHandler: ResultElementHandler, ChildlessHandler {
    typealias Result = ExperimentIcon

    var results = [Result]()

    func beginElement(attributes: [String: String]) throws {
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        guard !text.isEmpty else { throw ParseError.missingText }

        let format = attributes["format"]

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
