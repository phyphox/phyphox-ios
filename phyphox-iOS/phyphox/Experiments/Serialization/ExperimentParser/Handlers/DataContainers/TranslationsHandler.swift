//
//  TranslationsHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

private final class StringTranslationHandler: ChildLessResultHandler {
    private(set) var results = [Result]()

    typealias Result = (String, String)

    private var original: String?

    func beginElement(attributes: [String : String]) throws {
        original = attributes["original"]
    }

    func endElement(with text: String) throws {
        guard let original = original else { throw ParseError.missingAttribute("original") }

        results.append((original, text))
    }

    func clear() {
        results.removeAll()
    }
}

private final class TranslationHandler: LookupResultElementHandler {
    let handlers: [String : ElementHandler]

    typealias Result = (String, ExperimentTranslation)

    private(set) var results = [Result]()

    private let titleHandler = TextElementHandler()
    private let categoryHandler = TextElementHandler()
    private let descriptionHandler = TextElementHandler()

    private let stringHandler = StringTranslationHandler()

    private var locale: String?

    init() {
        handlers = ["title": titleHandler, "category": categoryHandler, "description": descriptionHandler]
    }

    func beginElement(attributes: [String : String]) throws {
        stringHandler.clear()
        locale = attributes["locale"]
    }

    func endElement(with text: String) throws {
        guard text.isEmpty else { throw ParseError.unexpectedText }

        guard let locale = locale else { throw ParseError.missingAttribute("locale") }

        let title = try titleHandler.expectSingleResult()
        let category = try categoryHandler.expectSingleResult()
        let description = try descriptionHandler.expectSingleResult()

        let strings = Dictionary(stringHandler.results, uniquingKeysWith: { first, _ in first })

        // TODO: Links?
        results.append((locale, ExperimentTranslation(withLocale: locale, strings: strings, titleString: title, descriptionString: description, categoryString: category, links: [:])))
    }
}

final class TranslationsHandler: AttributeLessResultHandler {
    typealias Result = ExperimentTranslationCollection

    private(set) var results = [Result]()

    private let translationHandler = TranslationHandler()

    func childHandler(for tagName: String) throws -> ElementHandler {
        guard tagName == "translation" else {
            throw ParseError.unexpectedElement
        }

        return translationHandler
    }

    func endElement(with text: String) throws {
        guard text.isEmpty else { throw ParseError.unexpectedText }

        let translations = Dictionary(translationHandler.results, uniquingKeysWith: { first, _ in first })

        results.append(ExperimentTranslationCollection(translations: translations, defaultLanguageCode: "en"))
    }
}
