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

    func beginElement(attributeContainer: XMLElementAttributeContainer) throws {
    }

    private enum Attribute: String, XMLAttributeKey {
        case label
    }

    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws {
        let attributes = attributeContainer.attributes(keyedBy: Attribute.self)

        let label = try attributes.nonEmptyString(for: .label)

        results.append(InfoViewElementDescriptor(label: label))
    }

    func getResult() throws -> ViewElementDescriptor {
        return try expectSingleResult()
    }
}
