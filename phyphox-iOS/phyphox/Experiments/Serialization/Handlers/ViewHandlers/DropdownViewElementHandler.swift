//
//  DropdownViewElementHandler.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 25.10.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

final class DropdownViewMapElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [DropdownViewMap]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case value
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        guard !text.isEmpty else {
            throw ElementHandlerError.missingText
        }

        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let value = attributes.optionalString(for: .value) ?? ""

        results.append(DropdownViewMap(value: value, replacement: text))
       
    }
}

struct DropdownViewElementDescriptor {
    var label: String
    
    let defaultValue: String?
    
    let outputBufferName: String
    
    let mappings: [DropdownViewMap]
}

final class DropdownViewElementHandler : ResultElementHandler, LookupElementHandler, ViewComponentElementHandler {
    
    var results = [ViewElementDescriptor]()
    
    var childHandlers: [String : ElementHandler] = [:]
    
    private let outputHandler = TextElementHandler()
    
    private let mapHandler = DropdownViewMapElementHandler()
    
    init() {
        childHandlers = ["output": outputHandler, "map": mapHandler]
    }
    
    private enum Attribute: String, AttributeKey {
        case label
        case defaultValue
    }
    
    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else {
            throw ElementHandlerError.missingElement("")
        }
        return results.removeFirst()
    }
    
    func startElement(attributes: AttributeContainer) throws {}
    
    func endElement(text: String, attributes: AttributeContainer) throws {
        
        let attributes = attributes.attributes(keyedBy: Attribute.self)
        
        let label = attributes.optionalString(for: .label) ?? ""
        
        let outputBufferName = try outputHandler.expectSingleResult()
        
        let defaultValue: String? = attributes.optionalString(for: .defaultValue) ?? ""
        
        let mappings = mapHandler.results
        
        results.append(.dropdown(DropdownViewElementDescriptor(label: label, defaultValue: defaultValue, outputBufferName: outputBufferName, mappings: mappings)))
        
    }
    
}
