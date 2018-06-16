//
//  InfoViewElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

struct InfoViewElementDescriptor: ViewElementDescriptor {
    let label: String
}

final class InfoViewElementHandler: ResultElementHandler, ChildlessElementHandler, ViewComponentElementHandler {
    typealias Result = InfoViewElementDescriptor

    var results = [Result]()

    func beginElement(attributes: XMLElementAttributes) throws {
    }

    func endElement(with text: String, attributes: XMLElementAttributes) throws {
        guard let label = attributes["label"], !label.isEmpty else {
            throw XMLElementParserError.missingAttribute("label")
        }

        results.append(InfoViewElementDescriptor(label: label))
    }

    func getResult() throws -> ViewElementDescriptor {
        return try expectSingleResult()
    }
}
