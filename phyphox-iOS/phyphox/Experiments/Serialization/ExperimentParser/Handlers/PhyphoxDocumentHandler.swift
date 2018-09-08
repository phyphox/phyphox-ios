//
//  PhyphoxExperimentFileRootElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class PhyphoxDocumentHandler: ResultElementHandler, LookupElementHandler, AttributelessElementHandler {
    var results: [Experiment] = []
    
    private let phyphoxHandler = PhyphoxElementHandler()
    var childHandlers: [String: ElementHandler]

    init() {
        childHandlers = ["phyphox": phyphoxHandler]
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        results.append(try phyphoxHandler.expectSingleResult())
    }
}
