//
//  TranslationsHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

private final class StringTranslationHandler: ResultElementHandler, ChildlessHandler {
    var results = [Result]()

    typealias Result = (String, String)

    func beginElement(attributes: [String : String]) throws {
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        guard let original = attributes["original"] else { throw ParseError.missingAttribute("original") }

        results.append((original, text))
    }

    func clear() {
        results.removeAll()
    }
}

private final class TranslationHandler: ResultElementHandler, LookupElementHandler {
    typealias Result = (String, ExperimentTranslation)

    var results = [Result]()

    private let titleHandler = TextElementHandler()
    private let categoryHandler = TextElementHandler()
    private let descriptionHandler = TextElementHandler()

    private let stringHandler = StringTranslationHandler()

    var handlers: [String : ElementHandler]

    init() {
        handlers = ["title": titleHandler, "category": categoryHandler, "description": descriptionHandler]
    }

    func beginElement(attributes: [String : String]) throws {
        stringHandler.clear()
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        guard text.isEmpty else { throw ParseError.unexpectedText }

        guard let locale = attributes["locale"] else { throw ParseError.missingAttribute("locale") }

        let title = try titleHandler.expectSingleResult()
        let category = try categoryHandler.expectSingleResult()
        let description = try descriptionHandler.expectSingleResult()

        let strings = Dictionary(stringHandler.results, uniquingKeysWith: { first, _ in first })

        // TODO: Links?
        results.append((locale, ExperimentTranslation(withLocale: locale, strings: strings, titleString: title, descriptionString: description, categoryString: category, links: [:])))
    }
}

final class TranslationsHandler: ResultElementHandler, LookupElementHandler, AttributelessHandler {
    typealias Result = ExperimentTranslationCollection

    var results = [Result]()

    private let translationHandler = TranslationHandler()

    var handlers: [String: ElementHandler]

    init() {
        handlers = ["translation": translationHandler]
    }

    func endElement(with text: String, attributes: [String: String]) throws {
        guard text.isEmpty else { throw ParseError.unexpectedText }

        let translations = Dictionary(translationHandler.results, uniquingKeysWith: { first, _ in first })

        results.append(ExperimentTranslationCollection(translations: translations, defaultLanguageCode: "en"))
    }
}
