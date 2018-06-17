//
//  TranslationsElementHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

private final class StringTranslationElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [Result]()

    typealias Result = (String, String)

    func beginElement(attributeContainer: XMLElementAttributeContainer) throws {}

    // Bug in Swift 4.1 compiler (https://bugs.swift.org/browse/SR-7153). Make private again when compiling with Swift 4.2
    /*private*/ enum Attribute: String, XMLAttributeKey {
        case original
    }

    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws {
        let attributes = attributeContainer.attributes(keyedBy: Attribute.self)

        let original = try attributes.attribute(for: .original)

        results.append((original, text))
    }

    func clear() {
        results.removeAll()
    }
}

private final class TranslationElementHandler: ResultElementHandler, LookupElementHandler {
    typealias Result = (String, ExperimentTranslation)

    var results = [Result]()

    private let titleHandler = TextElementHandler()
    private let categoryHandler = TextElementHandler()
    private let descriptionHandler = MultilineTextElementHandler()

    private let stringHandler = StringTranslationElementHandler()
    private let linkHandler = LinkElementHandler()

    var handlers: [String : ElementHandler]

    init() {
        handlers = ["title": titleHandler, "category": categoryHandler, "description": descriptionHandler, "string": stringHandler, "link": linkHandler]
    }

    func beginElement(attributeContainer: XMLElementAttributeContainer) throws {}

    // Bug in Swift 4.1 compiler (https://bugs.swift.org/browse/SR-7153). Make private again when compiling with Swift 4.2
    /*private*/ enum Attribute: String, XMLAttributeKey {
        case locale
    }

    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws {
        let attributes = attributeContainer.attributes(keyedBy: Attribute.self)

        let locale = try attributes.attribute(for: .locale)

        let title = try titleHandler.expectSingleResult()
        let category = try categoryHandler.expectSingleResult()
        let description = try descriptionHandler.expectSingleResult()

        let strings = Dictionary(stringHandler.results, uniquingKeysWith: { first, _ in first })

        let links = Dictionary(linkHandler.results.map({ ($0.label, $0.url) }), uniquingKeysWith: { first, _ in first })

        results.append((locale, ExperimentTranslation(withLocale: locale, strings: strings, titleString: title, descriptionString: description, categoryString: category, links: links)))
    }
}

final class TranslationsElementHandler: ResultElementHandler, LookupElementHandler, AttributelessElementHandler {
    typealias Result = [String: ExperimentTranslation]

    var results = [Result]()

    private let translationHandler = TranslationElementHandler()

    var handlers: [String: ElementHandler]

    init() {
        handlers = ["translation": translationHandler]
    }

    func endElement(with text: String, attributeContainer: XMLElementAttributeContainer) throws {
        let translations = Dictionary(translationHandler.results, uniquingKeysWith: { first, _ in first })

        results.append(translations)
    }
}
