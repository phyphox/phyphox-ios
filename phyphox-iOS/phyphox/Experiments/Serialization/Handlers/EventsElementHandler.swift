//
//  EventsElementHandler.swift
//  phyphox
//
//  Created by Sebastian Staacks on 18.12.20.
//  Copyright © 2020 RWTH Aachen. All rights reserved.
//

import Foundation

struct EventDescriptor {
    let experimentTime: Double
    let systemTime: Date
}

private final class EventElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [EventDescriptor]()

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case experimentTime, systemTime
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let experimentTime: Double = try attributes.value(for: .experimentTime)
        let systemTimestamp: Int64 = try attributes.value(for: .systemTime)
        let systemTime = Date(timeIntervalSince1970: Double(systemTimestamp)*0.001)

        results.append(EventDescriptor(experimentTime: experimentTime, systemTime: systemTime))
    }
}

struct EventsDescriptor {
    let types: [ExperimentTimeReference.TimeMappingEvent]
    let events: [EventDescriptor]
}

final class EventsElementHandler: ResultElementHandler {
    var results = [EventsDescriptor]()
    private var types: [ExperimentTimeReference.TimeMappingEvent] = []
    private let eventHandler = EventElementHandler()

    func childHandler(for elementName: String) throws -> ElementHandler {
        guard let type = ExperimentTimeReference.TimeMappingEvent(rawValue: elementName.uppercased()) else {
            throw ElementHandlerError.unexpectedChildElement(elementName)
        }
        types.append(type)
        return eventHandler
    }

    func clearChildHandlers() {
        types.removeAll()
        eventHandler.clear()
    }
    
    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case experimentTime, systemTime
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        results.append(EventsDescriptor(types: types, events: eventHandler.results))
    }
}
