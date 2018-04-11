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

    func beginElement(attributes: [String : String]) throws {
        result = nil

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
