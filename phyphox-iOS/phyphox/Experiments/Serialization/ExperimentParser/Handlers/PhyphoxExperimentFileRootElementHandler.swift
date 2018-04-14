//
//  PhyphoxExperimentFileRootElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class PhyphoxExperimentFileRootElementHandler: RootElementHandler, LookupElementHandler, AttributelessElementHandler {
    typealias Result = Experiment

    var result: Experiment?

    private let phyphoxHandler = PhyphoxElementHandler()

    var handlers: [String : ElementHandler]

    init() {
        handlers = ["phyphox": phyphoxHandler]
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        result = try phyphoxHandler.expectSingleResult()
    }
}
