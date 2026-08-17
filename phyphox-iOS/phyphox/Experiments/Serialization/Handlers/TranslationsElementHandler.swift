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

/// Element handler for the `link` child elements of a `translation` block. Unlike a link at the
/// root, the URL may be omitted (inherits from or removes the matched base link) and highlight is
/// kept optional so that an absent attribute can inherit the base link's state
/// (translation-link-matching in phyphox-docs).
private final class TranslatedLinkElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [ExperimentTranslatedLink]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case label
        case translation
        case highlight
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let label = try attributes.string(for: .label)
        let translation = attributes.optionalString(for: .translation)
        let highlighted: Bool? = try attributes.optionalValue(for: .highlight)

        let url: URL?
        if text.isEmpty {
            url = nil
        } else {
            guard let parsedURL = URL(string: text) else { throw ElementHandlerError.unexpectedAttributeValue("url") }
            url = parsedURL
        }

        results.append(ExperimentTranslatedLink(label: label, translation: translation, url: url, highlighted: highlighted))
    }
}

private final class TranslationElementHandler: ResultElementHandler, LookupElementHandler {
    var results = [(String, ExperimentTranslation)]()

    private let titleHandler = TextElementHandler()
    private let categoryHandler = TextElementHandler()
    private let descriptionHandler = MultilineTextElementHandler()

    private let stringHandler = StringTranslationElementHandler()
    private let linkHandler = TranslatedLinkElementHandler()

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

        let links = linkHandler.results
        var seenLabels = Set<String>()
        for link in links {
            guard seenLabels.insert(link.label).inserted else {
                throw ElementHandlerError.message("Duplicate link label \"\(link.label)\" in translation block \"\(locale)\"")
            }
        }

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
