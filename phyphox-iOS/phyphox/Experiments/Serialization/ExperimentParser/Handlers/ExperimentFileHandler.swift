//
//  ExperimentFileHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentFileHandler: RootElementHandler {
    typealias Result = Experiment

    private(set) var result: Experiment?

    private let phyphoxHandler = PhyphoxElementHandler()

    private(set) var locale = ""
    private(set) var version = "1.0"

    func beginElement(attributes: [String : String]) throws {
        result = nil
        locale = attributes["locale"] ?? ""
        version = attributes["version"] ?? "1.0"

        phyphoxHandler.clear()
    }

    func childHandler(for tagName: String) throws -> ElementHandler {
        guard tagName == "phyphox" else {
            throw ParseError.unexpectedElement
        }

        return phyphoxHandler
    }

    func endElement(with text: String) throws {
        guard let firstResult = phyphoxHandler.results.first else {
            throw ParseError.missingElement
        }

        guard phyphoxHandler.results.count == 1 else {
            throw ParseError.duplicateElement
        }

        result = firstResult
    }
}
