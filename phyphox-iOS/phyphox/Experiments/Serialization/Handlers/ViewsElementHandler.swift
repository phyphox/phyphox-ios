//
//  ViewsElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

// This file contains element handlers for the `views` child element (and its child elements) of the `phyphox` root element.

enum ViewElementDescriptor {
    case info(InfoViewElementDescriptor)
    case separator(SeparatorViewElementDescriptor)
    case value(ValueViewElementDescriptor)
    case edit(EditViewElementDescriptor)
    case button(ButtonViewElementDescriptor)
    case graph(GraphViewElementDescriptor)
    case depthGUI(DepthGUIViewElementDescriptor)
}

protocol ViewComponentElementHandler: ElementHandler {
    func nextResult() throws -> ViewElementDescriptor
}

struct ViewCollectionDescriptor {
    let label: String
    let views: [ViewElementDescriptor]
}

private final class ViewElementHandler: ResultElementHandler {
    var results = [ViewCollectionDescriptor]()

    private let infoHandler = InfoViewElementHandler()
    private let separatorHandler = SeparatorViewElementHandler()
    private let valueHandler = ValueViewElementHandler()
    private let editHandler = EditViewElementHandler()
    private let buttonhandler = ButtonViewElementHandler()
    private let graphHandler = GraphViewElementHandler()
    private let depthGUIHandler = DepthGUIViewElementHandler()

    private var elementOrder = [ViewComponentElementHandler]()

    func startElement(attributes: AttributeContainer) throws {}

    func childHandler(for elementName: String) throws -> ElementHandler {
        let handler: ViewComponentElementHandler

        switch elementName {
        case "info":
            handler = infoHandler
        case "separator":
            handler = separatorHandler
        case "value":
            handler = valueHandler
        case "edit":
            handler = editHandler
        case "button":
            handler = buttonhandler
        case "graph":
            handler = graphHandler
        case "depth-gui":
            handler = depthGUIHandler
        default:
            throw ElementHandlerError.unexpectedChildElement(elementName)
        }
        elementOrder.append(handler)

        return handler
    }

    private enum Attribute: String, AttributeKey {
        case label
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let label = try attributes.nonEmptyString(for: .label)

        let views = try elementOrder.map { try $0.nextResult() }

        guard !views.isEmpty else { throw ElementHandlerError.missingChildElement("view-element") }

        results.append(ViewCollectionDescriptor(label: label, views: views))
    }

    func clearChildHandlers() {
        elementOrder.removeAll()
        infoHandler.clear()
        separatorHandler.clear()
        valueHandler.clear()
        editHandler.clear()
        buttonhandler.clear()
        graphHandler.clear()
        depthGUIHandler.clear()
    }
}

final class ViewsElementHandler: ResultElementHandler, LookupElementHandler, AttributelessElementHandler {
    var results = [[ViewCollectionDescriptor]]()

    var childHandlers: [String: ElementHandler]

    private let viewHandler = ViewElementHandler()

    init() {
        childHandlers = ["view": viewHandler]
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        results.append(viewHandler.results)
    }
}
