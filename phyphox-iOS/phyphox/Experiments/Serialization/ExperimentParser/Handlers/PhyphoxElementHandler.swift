//
//  PhyphoxElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class PhyphoxElementHandler: ResultElementHandler, LookupElementHandler {
    typealias Result = Experiment
    
    var results = [Result]()

    var handlers: [String: ElementHandler]

    private let titleHandler = TextElementHandler()
    private let categoryHandler = TextElementHandler()
    private let descriptionHandler = TextElementHandler()
    private let iconHandler = IconHandler()
    private let linkHandler = LinkHandler()
    private let dataContainersHandler = DataContainersHandler()
    private let translationsHandler = TranslationsHandler()
    private let inputHandler = InputHandler()
    private let outputHandler = OutputHandler()
    private let analysisHandler = AnalysisHandler()

    init() {
        handlers = ["title": titleHandler, "category": categoryHandler, "description": descriptionHandler, "icon": iconHandler, "link": linkHandler, "data-containers": dataContainersHandler, "translations": translationsHandler, "input": inputHandler, "outputHandler": outputHandler, "analysis": analysisHandler]
    }

    func beginElement(attributes: [String : String]) throws {
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        let locale = attributes["locale"] ?? "en"
        guard let version = attributes["version"] else {
            throw ParseError.missingAttribute("version")
        }

        let title = try titleHandler.expectSingleResult()
        let category = try categoryHandler.expectSingleResult()
        let description = try descriptionHandler.expectSingleResult()
        let icon = try iconHandler.expectOptionalResult() ?? ExperimentIcon(string: title, image: nil)
        let dataContainers = try dataContainersHandler.results
        
        let translations = try translationsHandler.expectOptionalResult()
        let input = try inputHandler.expectOptionalResult()
        let output = try outputHandler.expectOptionalResult()
        let analysis = try analysisHandler.expectOptionalResult()


    }
}
