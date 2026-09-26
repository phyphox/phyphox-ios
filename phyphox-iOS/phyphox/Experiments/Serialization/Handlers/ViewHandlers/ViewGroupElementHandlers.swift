//
//  ViewGroupElementHandlers.swift
//  phyphox
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import Foundation

// This file contains element handlers for the view groups of file format 1.21 (phyphox-docs docs/file-format/views/groups.md):
// vertical, horizontal, grid, stack, transform and the input children of transform - and the child dispatch they share with
// the view element itself.

///vertical, horizontal and stack: the children in document order and, for horizontal, each child's weight (1 elsewhere)
struct GroupViewElementDescriptor {
    let visibility: String
    let children: [ViewElementDescriptor]
    let weights: [CGFloat]
}

struct GridViewElementDescriptor {
    let visibility: String
    let maxWidth: CGFloat
    let fillLastRow: Bool
    let children: [ViewElementDescriptor]
}

enum TransformProperty: String, CaseInsensitiveAttributeDecodable, CaseIterable {
    case scale, scaleX, scaleY, translateX, translateY, rotate, opacity
}

///One input of a transform: a data container or a constant, mapped linearly onto a property
struct TransformInputDescriptor {
    let property: TransformProperty
    let bufferName: String?
    let value: Double?
    let min: Double
    let max: Double
    let mapMin: Double
    let mapMax: Double
    let clamp: Bool
}

struct TransformViewElementDescriptor {
    let visibility: String
    let originX: CGFloat
    let originY: CGFloat
    let inputs: [TransformInputDescriptor]
    let child: ViewElementDescriptor
}

///Which children a container accepts (the nesting table of groups.md)
enum ViewChildSet {
    case all        //view, vertical, horizontal, grid: every view element
    case stack      //info, separator, value, graph, image, transform
    case transform  //exactly one of info, separator, value, graph, image (input is read by the transform handler itself)
}

///Reads the per-child weight of a horizontal group around the child's own handler
private final class ViewChildElementHandler: ElementHandler {
    private let inner: ViewComponentElementHandler
    private let readsWeight: Bool
    private(set) var weight: CGFloat = 1

    init(_ inner: ViewComponentElementHandler, readsWeight: Bool) {
        self.inner = inner
        self.readsWeight = readsWeight
    }

    private enum Attribute: String, AttributeKey {
        case weight
    }

    func startElement(attributes: AttributeContainer) throws {
        try inner.startElement(attributes: attributes)
    }

    func childHandler(for elementName: String) throws -> ElementHandler {
        return try inner.childHandler(for: elementName)
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        if readsWeight {
            weight = try attributes.attributes(keyedBy: Attribute.self).optionalValue(for: .weight) ?? 1
        }
        try inner.endElement(text: text, attributes: attributes)
    }

    func nextResult() throws -> ViewElementDescriptor {
        return try inner.nextResult()
    }

    func clear() {
        inner.clear()
    }

    func clearChildHandlers() {
        inner.clearChildHandlers()
    }
}

///Dispatches the child elements of a view or a group, one fresh handler per child. Nothing is shared between levels: the
///parser resets a handler on every element start (clearChildHandlers), which would wipe an outer group's children when an
///inner group of the same type starts, so every group and every view creates its own container.
final class ViewElementContainerHandler {
    private let childSet: ViewChildSet
    private let readsWeight: Bool
    private var elementOrder = [ViewChildElementHandler]()

    init(childSet: ViewChildSet, readsWeight: Bool) {
        self.childSet = childSet
        self.readsWeight = readsWeight
    }

    func childHandler(for elementName: String) throws -> ElementHandler {
        let inner: ViewComponentElementHandler

        switch elementName.lowercased() { //Element names are matched case-insensitively
        case "info":
            inner = InfoViewElementHandler()
        case "separator":
            inner = SeparatorViewElementHandler()
        case "value":
            inner = ValueViewElementHandler()
        case "graph":
            inner = GraphViewElementHandler()
        case "image":
            inner = ImageViewElementHandler()
        case "edit":
            guard childSet == .all else { throw ElementHandlerError.unexpectedChildElement(elementName) }
            inner = EditViewElementHandler()
        case "button":
            guard childSet == .all else { throw ElementHandlerError.unexpectedChildElement(elementName) }
            inner = ButtonViewElementHandler()
        case "depth-gui":
            guard childSet == .all else { throw ElementHandlerError.unexpectedChildElement(elementName) }
            inner = DepthGUIViewElementHandler()
        case "toggle":
            guard childSet == .all else { throw ElementHandlerError.unexpectedChildElement(elementName) }
            inner = SwitchViewElementHandler()
        case "dropdown":
            guard childSet == .all else { throw ElementHandlerError.unexpectedChildElement(elementName) }
            inner = DropdownViewElementHandler()
        case "slider":
            guard childSet == .all else { throw ElementHandlerError.unexpectedChildElement(elementName) }
            inner = SliderViewElementHandler()
        case "camera-gui":
            guard childSet == .all else { throw ElementHandlerError.unexpectedChildElement(elementName) }
            inner = CameraViewElementHandler()
        case "vertical":
            guard childSet == .all else { throw ElementHandlerError.unexpectedChildElement(elementName) }
            inner = GroupViewElementHandler(kind: .vertical)
        case "horizontal":
            guard childSet == .all else { throw ElementHandlerError.unexpectedChildElement(elementName) }
            inner = GroupViewElementHandler(kind: .horizontal)
        case "grid":
            guard childSet == .all else { throw ElementHandlerError.unexpectedChildElement(elementName) }
            inner = GridViewElementHandler()
        case "stack":
            guard childSet == .all else { throw ElementHandlerError.unexpectedChildElement(elementName) }
            inner = GroupViewElementHandler(kind: .stack)
        case "transform":
            guard childSet == .stack else { throw ElementHandlerError.unexpectedChildElement(elementName) }
            inner = TransformViewElementHandler()
        default:
            throw ElementHandlerError.unexpectedChildElement(elementName)
        }

        let handler = ViewChildElementHandler(inner, readsWeight: readsWeight)
        elementOrder.append(handler)

        return handler
    }

    func results() throws -> (elements: [ViewElementDescriptor], weights: [CGFloat]) {
        let elements = try elementOrder.map { try $0.nextResult() }
        return (elements, elementOrder.map { $0.weight })
    }

    func clear() {
        elementOrder.removeAll()
    }
}

///vertical, horizontal and stack; an empty group is allowed, like on Android
final class GroupViewElementHandler: ResultElementHandler, ViewComponentElementHandler {
    enum Kind {
        case vertical, horizontal, stack
    }

    var results = [ViewElementDescriptor]()

    private let kind: Kind
    private var container: ViewElementContainerHandler

    init(kind: Kind) {
        self.kind = kind
        container = ViewElementContainerHandler(childSet: kind == .stack ? .stack : .all, readsWeight: kind == .horizontal)
    }

    func startElement(attributes: AttributeContainer) throws {}

    func childHandler(for elementName: String) throws -> ElementHandler {
        return try container.childHandler(for: elementName)
    }

    private enum Attribute: String, AttributeKey {
        case label
        case visibility
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)
        let visibility = attributes.optionalString(for: .visibility) ?? ""

        let (children, weights) = try container.results()
        let descriptor = GroupViewElementDescriptor(visibility: visibility, children: children, weights: weights)

        switch kind {
        case .vertical:
            results.append(.vertical(descriptor))
        case .horizontal:
            results.append(.horizontal(descriptor))
        case .stack:
            results.append(.stack(descriptor))
        }
    }

    func clearChildHandlers() {
        container.clear()
    }

    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}

final class GridViewElementHandler: ResultElementHandler, ViewComponentElementHandler {
    var results = [ViewElementDescriptor]()

    private let container = ViewElementContainerHandler(childSet: .all, readsWeight: false)

    func startElement(attributes: AttributeContainer) throws {}

    func childHandler(for elementName: String) throws -> ElementHandler {
        return try container.childHandler(for: elementName)
    }

    private enum Attribute: String, AttributeKey {
        case label
        case visibility
        case maxWidth
        case fillLastRow
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)
        let visibility = attributes.optionalString(for: .visibility) ?? ""

        guard let maxWidth: CGFloat = try attributes.optionalValue(for: .maxWidth) else {
            throw ElementHandlerError.missingAttribute("maxWidth")
        }
        let fillLastRow = try attributes.optionalValue(for: .fillLastRow) ?? false

        let children = try container.results().elements

        results.append(.grid(GridViewElementDescriptor(visibility: visibility, maxWidth: maxWidth, fillLastRow: fillLastRow, children: children)))
    }

    func clearChildHandlers() {
        container.clear()
    }

    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}

private final class TransformInputElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [TransformInputDescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum InputType: String, CaseInsensitiveAttributeDecodable, CaseIterable {
        case buffer, value
    }

    private enum Attribute: String, AttributeKey {
        case `as`
        case type
        case min
        case max
        case mapMin
        case mapMax
        case clamp
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        guard !text.isEmpty else {
            throw ElementHandlerError.missingText
        }

        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let property: TransformProperty = try attributes.value(for: .as)
        let type: InputType = try attributes.optionalValue(for: .type) ?? .buffer
        let min: Double = try attributes.optionalValue(for: .min) ?? 0
        let max: Double = try attributes.optionalValue(for: .max) ?? 1
        let mapMin: Double = try attributes.optionalValue(for: .mapMin) ?? 0
        let mapMax: Double = try attributes.optionalValue(for: .mapMax) ?? 1
        let clamp = try attributes.optionalValue(for: .clamp) ?? false

        switch type {
        case .buffer:
            results.append(TransformInputDescriptor(property: property, bufferName: text, value: nil, min: min, max: max, mapMin: mapMin, mapMax: mapMax, clamp: clamp))
        case .value:
            guard let value = Double(text) else {
                throw ElementHandlerError.unexpectedAttributeValue("value")
            }
            results.append(TransformInputDescriptor(property: property, bufferName: nil, value: value, min: min, max: max, mapMin: mapMin, mapMax: mapMax, clamp: clamp))
        }
    }
}

///transform: only directly inside a stack (the stack's container refuses it elsewhere), exactly one wrapped element
final class TransformViewElementHandler: ResultElementHandler, ViewComponentElementHandler {
    var results = [ViewElementDescriptor]()

    private let container = ViewElementContainerHandler(childSet: .transform, readsWeight: false)
    private let inputHandler = TransformInputElementHandler()

    func startElement(attributes: AttributeContainer) throws {}

    func childHandler(for elementName: String) throws -> ElementHandler {
        if elementName.lowercased() == "input" {
            return inputHandler
        }
        return try container.childHandler(for: elementName)
    }

    private enum Attribute: String, AttributeKey {
        case label
        case visibility
        case originX
        case originY
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)
        let visibility = attributes.optionalString(for: .visibility) ?? ""
        let originX: CGFloat = try attributes.optionalValue(for: .originX) ?? 0.5
        let originY: CGFloat = try attributes.optionalValue(for: .originY) ?? 0.5

        let children = try container.results().elements
        guard children.count == 1 else {
            throw ElementHandlerError.message("A transform wraps exactly one view element.")
        }

        results.append(.transform(TransformViewElementDescriptor(visibility: visibility, originX: originX, originY: originY, inputs: inputHandler.results, child: children[0])))
    }

    func clearChildHandlers() {
        container.clear()
        inputHandler.clear()
    }

    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}
