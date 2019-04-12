//
//  TranslationsElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

// This file contains element handlers for the `translations` child element (and its child elements) of the `phyphox` root element.

private final class StringTranslationElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [(String, String)]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case original
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let original = try attributes.string(for: .original)

        results.append((original, text))
    }

    func clear() {
        results.removeAll()
    }
}

private final class TranslationElementHandler: ResultElementHandler, LookupElementHandler {
    var results = [(String, ExperimentTranslation)]()

    private let titleHandler = TextElementHandler()
    private let categoryHandler = TextElementHandler()
    private let descriptionHandler = MultilineTextElementHandler()

    private let stringHandler = StringTranslationElementHandler()
    private let linkHandler = LinkElementHandler()

    var childHandlers: [String : ElementHandler]

    init() {
        childHandlers = ["title": titleHandler, "category": categoryHandler, "description": descriptionHandler, "string": stringHandler, "link": linkHandler]
    }

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case locale
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let locale = try attributes.string(for: .locale)

        let title = try titleHandler.expectOptionalResult()
        let category = try categoryHandler.expectOptionalResult()
        let description = try descriptionHandler.expectOptionalResult()

        let strings = Dictionary(stringHandler.results, uniquingKeysWith: { first, _ in first })

        let links = Dictionary(linkHandler.results.map({ ($0.label, $0.url) }), uniquingKeysWith: { first, _ in first })

        results.append((locale, ExperimentTranslation(withLocale: locale, strings: strings, titleString: title, descriptionString: description, categoryString: category, links: links)))
    }
}

final class TranslationsElementHandler: ResultElementHandler, LookupElementHandler, AttributelessElementHandler {
    var results = [[String: ExperimentTranslation]]()

    private let translationHandler = TranslationElementHandler()

    var childHandlers: [String: ElementHandler]

    init() {
        childHandlers = ["translation": translationHandler]
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let translations = Dictionary(translationHandler.results, uniquingKeysWith: { first, _ in first })

        results.append(translations)
    }
}
