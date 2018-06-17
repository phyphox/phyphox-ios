//
//  DataContainersElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

typealias BufferDescriptor = (name: String, size: Int, baseContents: [Double], staticBuffer: Bool)

private final class DataContainerElementHandler: ResultElementHandler, ChildlessElementHandler {
    typealias Result = BufferDescriptor

    var results = [Result]()

    func beginElement(attributeContainer: XMLElementAttributeContainer) throws {
    }

    // Bug in Swift 4.1 compiler (https://bugs.swift.org/browse/SR-7153). Make private again when compiling with Swift 4.2
    /*private*/ enum Attribute: String, XMLAttributeKey {
        case size
        case staticKey = "static"
        case initKey = "init"
    }

    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws {
        guard !text.isEmpty else { throw XMLElementParserError.missingText }

        let attributes = attributeContainer.attributes(keyedBy: Attribute.self)

        let size = try attributes.optionalAttribute(for: .size) ?? 1

        let baseContents = (attributes.optionalString(for: .initKey) as String?).map { $0.components(separatedBy: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) } } ?? []
        let staticBuffer = try attributes.optionalAttribute(for: .staticKey) ?? false

        results.append((text, size, baseContents, staticBuffer))
    }
}

final class DataContainersElementHandler: ResultElementHandler, LookupElementHandler, AttributelessElementHandler {
    typealias Result = [BufferDescriptor]

    var handlers: [String: ElementHandler]

    var results = [Result]()

    private let containerHandler = DataContainerElementHandler()

    init() {
        handlers = ["container": containerHandler]
    }

    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws {
        results.append(containerHandler.results)
    }
}
