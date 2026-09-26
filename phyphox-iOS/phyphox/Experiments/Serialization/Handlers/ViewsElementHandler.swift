//
//  ViewsElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

// This file contains element handlers for the `views` child element (and its child elements) of the `phyphox` root element.

//indirect: the view groups of file format 1.21 carry their children (ViewGroupElementHandlers.swift)
indirect enum ViewElementDescriptor {
    case info(InfoViewElementDescriptor)
    case separator(SeparatorViewElementDescriptor)
    case value(ValueViewElementDescriptor)
    case edit(EditViewElementDescriptor)
    case button(ButtonViewElementDescriptor)
    case graph(GraphViewElementDescriptor)
    case depthGUI(DepthGUIViewElementDescriptor)
    case image(ImageViewElementDescriptor)
    case switchView(SwitchViewElementDescriptor)
    case dropdown(DropdownViewElementDescriptor)
    case slider(SliderViewElementDescriptor)
    case camera(CameraViewElementDescriptor)
    case vertical(GroupViewElementDescriptor)
    case horizontal(GroupViewElementDescriptor)
    case grid(GridViewElementDescriptor)
    case stack(GroupViewElementDescriptor)
    case transform(TransformViewElementDescriptor)
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

    //The child dispatch is shared with the view groups (ViewGroupElementHandlers.swift); a fresh container per view
    private var container = ViewElementContainerHandler(childSet: .all, readsWeight: false)

    func startElement(attributes: AttributeContainer) throws {}

    func childHandler(for elementName: String) throws -> ElementHandler {
        return try container.childHandler(for: elementName)
    }

    private enum Attribute: String, AttributeKey {
        case label
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let label = try attributes.nonEmptyString(for: .label)

        let views = try container.results().elements

        guard !views.isEmpty else { throw ElementHandlerError.missingChildElement("view-element") }

        results.append(ViewCollectionDescriptor(label: label, views: views))
    }

    func clearChildHandlers() {
        container = ViewElementContainerHandler(childSet: .all, readsWeight: false)
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
