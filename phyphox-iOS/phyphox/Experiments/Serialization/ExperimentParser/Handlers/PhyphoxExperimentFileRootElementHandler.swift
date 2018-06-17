//
//  PhyphoxExperimentFileRootElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class PhyphoxExperimentFileRootElementHandler: ResultElementHandler, LookupElementHandler, AttributelessElementHandler {
    typealias Result = Experiment

    var results: [Experiment] = []

    private let phyphoxHandler = PhyphoxElementHandler()

    var handlers: [String : ElementHandler]

    init() {
        handlers = ["phyphox": phyphoxHandler]
    }

    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws {
        results.append(try phyphoxHandler.expectSingleResult())
    }
}
