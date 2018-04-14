//
//  ViewsElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

protocol ViewElementDescriptor {
}

protocol ViewComponentElementHandler: ElementHandler {
    func getResult() throws -> ViewElementDescriptor
}

struct ViewCollectionDescriptor {
    let label: String
    
    let views: [(tagName: String, descriptor: ViewElementDescriptor)]
}

private final class ViewElementHandler: ResultElementHandler {
    typealias Result = ViewCollectionDescriptor

    var results = [ViewCollectionDescriptor]()

    private var handlers = [(tagName: String, handler: ViewComponentElementHandler)]()

    func beginElement(attributes: [String: String]) throws {
    }

    func childHandler(for tagName: String) throws -> ElementHandler {
        let handler: ViewComponentElementHandler

        if tagName == "info" {
            handler = InfoViewElementHandler()
        }
        else if tagName == "separator" {
            handler = SeparatorViewElementHandler()
        }
        else if tagName == "value" {
            handler = ValueViewElementHandler()
        }
        else if tagName == "edit" {
            handler = EditViewElementHandler()
        }
        else if tagName == "button" {
            handler = ButtonViewElementHandler()
        }
        else if tagName == "graph" {
            handler = GraphViewElementHandler()
        }
        else {
            throw XMLElementParserError.unexpectedChildElement(tagName)
        }

        handlers.append((tagName, handler))

        return handler
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        guard let label = attributes["label"], !label.isEmpty else {
            throw XMLElementParserError.missingAttribute("label")
        }

        let views = try handlers.map { ($0.tagName, try $0.handler.getResult()) }

        guard !views.isEmpty else {
            throw XMLElementParserError.missingChildElement("view-element")
        }

        results.append(ViewCollectionDescriptor(label: label, views: views))
    }

    func clearChildHandlers() {
        handlers.removeAll()
    }
}

final class ViewsElementHandler: ResultElementHandler, LookupElementHandler, AttributelessHandler {
    typealias Result = [ViewCollectionDescriptor]

    var results = [Result]()

    var handlers: [String: ElementHandler]

    private let viewHandler = ViewElementHandler()

    init() {
        handlers = ["view": viewHandler]
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        results.append(viewHandler.results)
    }
}
