//
//  ViewsHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

protocol ViewElementDescriptor {
}

protocol ViewComponentHandler: ElementHandler {
    func getResult() throws -> ViewElementDescriptor
}

struct ViewCollectionDescriptor {
    let label: String
    
    let views: [(tagName: String, descriptor: ViewElementDescriptor)]
}

private final class ViewHandler: ResultElementHandler {
    typealias Result = ViewCollectionDescriptor

    var results = [ViewCollectionDescriptor]()

    private var handlers = [(tagName: String, handler: ViewComponentHandler)]()

    func beginElement(attributes: [String: String]) throws {
    }

    func childHandler(for tagName: String) throws -> ElementHandler {
        let handler: ViewComponentHandler

        if tagName == "info" {
            handler = InfoViewHandler()
        }
        else if tagName == "separator" {
            handler = SeparatorViewHandler()
        }
        else if tagName == "value" {
            handler = ValueViewHandler()
        }
        else if tagName == "edit" {
            handler = EditViewHandler()
        }
        else if tagName == "button" {
            handler = ButtonViewHandler()
        }
        else if tagName == "graph" {
            handler = GraphViewHandler()
        }
        else {
            throw ParseError.unexpectedChildElement(tagName)
        }

        handlers.append((tagName, handler))

        return handler
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        guard let label = attributes["label"], !label.isEmpty else {
            throw ParseError.missingAttribute("label")
        }

        let views = try handlers.map { ($0.tagName, try $0.handler.getResult()) }

        guard !views.isEmpty else {
            throw ParseError.missingChildElement("view-element")
        }

        results.append(ViewCollectionDescriptor(label: label, views: views))
    }

    func clearChildHandlers() {
        handlers.removeAll()
    }
}

final class ViewsHandler: ResultElementHandler, LookupElementHandler, AttributelessHandler {
    typealias Result = [ViewCollectionDescriptor]

    var results = [Result]()

    var handlers: [String: ElementHandler]

    private let viewHandler = ViewHandler()

    init() {
        handlers = ["view": viewHandler]
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        results.append(viewHandler.results)
    }
}
