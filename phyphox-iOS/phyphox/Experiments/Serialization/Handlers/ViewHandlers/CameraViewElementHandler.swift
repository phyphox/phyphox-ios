//
//  CameraViewElementHandler.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 07.09.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation

struct CameraViewElementDescriptor {
    let label: String
    let aspectRatio: CGFloat
}

final class CameraViewElementHandler: ResultElementHandler, ChildlessElementHandler, ViewComponentElementHandler {
    var results = [ViewElementDescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case label
        case aspectRatio
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let label = attributes.optionalString(for: .label) ?? ""
        
        let aspectRatio: CGFloat = try attributes.optionalValue(for: .aspectRatio) ?? 2.5

        results.append(.camera(CameraViewElementDescriptor(label: label, aspectRatio: aspectRatio)))
    }

    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}
