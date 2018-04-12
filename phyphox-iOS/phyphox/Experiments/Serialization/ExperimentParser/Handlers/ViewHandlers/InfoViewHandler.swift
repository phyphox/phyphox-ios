//
//  InfoViewHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

struct InfoViewElementDescriptor: ViewElementDescriptor {
    let label: String
}

final class InfoViewHandler: ResultElementHandler, ChildlessHandler, ViewComponentHandler {
    typealias Result = InfoViewElementDescriptor

    var results = [Result]()

    func beginElement(attributes: [String : String]) throws {
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        guard let label = attributes["label"], !label.isEmpty else {
            throw ParseError.missingAttribute("label")
        }

        results.append(InfoViewElementDescriptor(label: label))
    }

    func result() throws -> ViewElementDescriptor {
        return try expectSingleResult()
    }
}
