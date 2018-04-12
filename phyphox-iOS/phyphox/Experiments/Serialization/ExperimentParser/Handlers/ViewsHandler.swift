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
    func result() throws -> ViewElementDescriptor
}

struct ViewCollectionDescriptor {
    let label: String
    
    let views: [ViewElementDescriptor]
}

private final class ViewHandler: ResultElementHandler {
    typealias Result = ViewCollectionDescriptor

    var results = [ViewCollectionDescriptor]()

    private var handlers = [ViewComponentHandler]()

    func beginElement(attributes: [String : String]) throws {
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
            throw ParseError.unexpectedElement
        }

        handlers.append(handler)

        return handler
    }

    func endElement(with text: String, attributes: [String : String]) throws {
        guard let label = attributes["label"], !label.isEmpty else {
            throw ParseError.missingAttribute("label")
        }

        let views = try handlers.map { try $0.result() }

        guard !views.isEmpty else {
            throw ParseError.missingElement
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
