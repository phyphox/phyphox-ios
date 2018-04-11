//
//  ExperimentFileHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentFileHandler: RootElementHandler, LookupElementHandler {
    typealias Result = Experiment

    var result: Experiment?

    private let phyphoxHandler = PhyphoxElementHandler()

    var handlers: [String : ElementHandler]

    private(set) var locale = ""
    private(set) var version = "1.0"

    init() {
        handlers = ["phyphox": phyphoxHandler]
    }

    func beginElement(attributes: [String : String]) throws {
        result = nil
        locale = attributes["locale"] ?? ""
        version = attributes["version"] ?? "1.0"
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        result = try phyphoxHandler.expectSingleResult()
    }
}
