//
//  PhyphoxElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class PhyphoxElementHandler: LookupResultElementHandler, ChildElementHandler {
    typealias Result = Experiment
    typealias Parent = ExperimentFileHandler

    private(set) var results = [Result]()

    let handlers: [String: ElementHandler]

    private let titleHandler = TextElementHandler()
    private let categoryHandler = TextElementHandler()
    private let descriptionHandler = TextElementHandler()
    private let iconHandler = IconHandler()
    private let linkHandler = LinkHandler()
    private let dataContainersHandler = DataContainersHandler()
    private let translationsHandler = TranslationsHandler()

    let parent: ExperimentFileHandler?

    init(parent: Parent) {
        self.parent = parent
        handlers = ["title": titleHandler, "category": categoryHandler, "description": descriptionHandler, "icon": iconHandler, "link": linkHandler, "data-containers": dataContainersHandler, "translations": translationsHandler]

        translationsHandler.parent = self
    }

    func beginElement(attributes: [String: String]) throws {
        guard attributes.isEmpty else {
            throw ParseError.unexpectedAttribute
        }
    }

    func endElement(with text: String) throws {
        let title = try titleHandler.expectSingleResult()
        let category = try categoryHandler.expectSingleResult()
        let description = try descriptionHandler.expectSingleResult()
        let icon = try iconHandler.expectOptionalResult() ?? ExperimentIcon(string: title, image: nil)
        let dataContainers = try dataContainersHandler.results
        let translations = try translationsHandler.expectSingleResult()
        
    }

    func clear() {
        results.removeAll()
    }
}
