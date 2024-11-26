//
//  DropdownViewElementHandler.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 25.10.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

struct DropdownViewElementDescriptor {
    var label: String
    
    let dropDownItems: String?
    
    let defaultValue: Double?
    
    let outputBufferName: String
}

final class DropdownViewElementHandler : ResultElementHandler, LookupElementHandler, ViewComponentElementHandler {
    
    var results = [ViewElementDescriptor]()
    
    var childHandlers: [String : ElementHandler] = [:]
    
    private let outputHandler = TextElementHandler()
    
    init() {
        childHandlers = ["output": outputHandler]
    }
    
    private enum Attribute: String, AttributeKey {
        case label
        case defaultValue
        case dropdownItems
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
        
        let dropDownList = attributes.optionalString(for: .dropdownItems)
        
        let outputBufferName = try outputHandler.expectSingleResult()
        
        let defaultValue: Double? = try attributes.optionalValue(for: .defaultValue)
        
        results.append(.dropdown(DropdownViewElementDescriptor(label: label, dropDownItems: dropDownList , defaultValue: defaultValue, outputBufferName: outputBufferName )))
        
    }
    
}
