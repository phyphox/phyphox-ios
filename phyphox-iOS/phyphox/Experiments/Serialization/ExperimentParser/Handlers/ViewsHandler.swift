//
//  ViewsHandler.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.04.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class ViewsHandler: ResultElementHandler, LookupElementHandler {
    typealias Result = Void

    var results = [Result]()

    var handlers: [String: ElementHandler]

    init() {
        handlers = [:]
    }

    func beginElement(attributes: [String : String]) throws {

    }

    func endElement(with text: String, attributes: [String : String]) throws {

    }
}
