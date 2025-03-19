//
//  SwitchViewElementHandler.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 22.10.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation


struct SwitchViewElementDescriptor {
    let label: String
    let defaultValue: Double
    
    let outputBufferName: String
}


final class SwitchViewElementHandler: ResultElementHandler, LookupElementHandler, ViewComponentElementHandler {
    var results = [ViewElementDescriptor]()
    
    var childHandlers: [String : ElementHandler] = [:]
    
    private let outputHandler = TextElementHandler()
    
    init() {
        childHandlers = ["output": outputHandler]
    }
    
    private enum Attribute: String, AttributeKey {
        case label
        case defaultValue = "default"
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
        
        let defaultValue = try attributes.optionalValue(for: .defaultValue) ?? 0.0
        
        results.append(.switchView(SwitchViewElementDescriptor(label: label, defaultValue: defaultValue, outputBufferName: outputBufferName)))
        
    }
    
    
}
