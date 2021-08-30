//
//  NetworkElementHandler.swift
//  phyphox
//
//  Created by Sebastian Staacks on 28.11.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation

struct NetworkConnectionSendDescriptor {
    let id: String
    enum SendableType: String, AttributeKey, LosslessStringConvertible {
        case meta
        case buffer
        case time
    }
    let type: SendableType
    let name: String
    let additionalAttributes: [String:String]
}

private final class NetworkConnectionSendElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [NetworkConnectionSendDescriptor]()
    
    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case id
        case type
        case datatype
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let id = try attributes.nonEmptyString(for: .id)
        let type: NetworkConnectionSendDescriptor.SendableType = try attributes.optionalValue(for: .type) ?? NetworkConnectionSendDescriptor.SendableType.buffer
        var additionalAttributes = [String:String]()
        if let datatype = attributes.optionalString(for: .datatype) {
            additionalAttributes[Attribute.datatype.rawValue] = datatype
        }
        
        guard !(text.isEmpty && type != .time) else { throw ElementHandlerError.missingText }
        
        results.append(NetworkConnectionSendDescriptor(id: id, type: type, name: text, additionalAttributes: additionalAttributes))
    }

    func clear() {
        results.removeAll()
    }
}

struct NetworkConnectionReceiveDescriptor {
    let id: String
    let clear: Bool
    let name: String
}

private final class NetworkConnectionReceiveElementHandler: ResultElementHandler, ChildlessElementHandler {
    var results = [NetworkConnectionReceiveDescriptor]()
    
    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case id
        case clear
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        guard !text.isEmpty else { throw ElementHandlerError.missingText }

        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let id = try attributes.nonEmptyString(for: .id)
        let clear = try attributes.optionalValue(for: .clear) ?? false
        results.append(NetworkConnectionReceiveDescriptor(id: id, clear: clear, name: text))
    }

    func clear() {
        results.removeAll()
    }
}

struct NetworkConnectionDescriptor {
    let id: String?
    let privacyURL: String?
    
    let address: String
    let discovery: NetworkDiscovery?
    let autoConnect: Bool
    let service: NetworkService
    let conversion: NetworkConversion
    
    let send: [NetworkConnectionSendDescriptor]
    let receive: [NetworkConnectionReceiveDescriptor]
    let interval: Double
}

private final class NetworkConnectionElementHandler: ResultElementHandler, LookupElementHandler {
    var results = [NetworkConnectionDescriptor]()

    var childHandlers: [String: ElementHandler]

    private let sendHandler = NetworkConnectionSendElementHandler()
    private let receiveHandler = NetworkConnectionReceiveElementHandler()

    init() {
        childHandlers = ["send": sendHandler, "receive": receiveHandler]
    }

    func startElement(attributes: AttributeContainer) throws {}

    private enum Attribute: String, AttributeKey {
        case id
        case privacy
        case address
        case discovery
        case discoveryAddress
        case autoConnect
        case service
        case conversion
        case interval
        case sendTopic
        case receiveTopic
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)

        let id = attributes.optionalString(for: .id)
        let privacy = attributes.optionalString(for: .privacy)
        let address = try attributes.nonEmptyString(for: .address)
        let discoveryStr = attributes.optionalString(for: .discovery)
        let discovery: NetworkDiscovery?
        let sendTopic = attributes.optionalString(for: .sendTopic)
        let receiveTopic = attributes.optionalString(for: .receiveTopic)
        
        switch discoveryStr {
        case "http": discovery = HttpNetworkDiscovery(address: try attributes.nonEmptyString(for: .discoveryAddress))
        default: discovery = nil
        }
        
        let autoConnect: Bool = try attributes.optionalValue(for: .autoConnect) ?? false
        let serviceStr = try attributes.nonEmptyString(for: .service)
        let service: NetworkService
        
        switch serviceStr {
        case "http/get":  service = HttpGetService()
        case "http/post": service = HttpPostService()
        case "mqtt/csv":  service = MqttCsvService(receiveTopic: receiveTopic)
        case "mqtt/json":
            guard let sendTopic = sendTopic else {
                throw ElementHandlerError.message("sendTopic must be set for the mqtt/json service. Use mqtt/csv if you do not intent to send anything.")
            }
            service = MqttJsonService(receiveTopic: receiveTopic, sendTopic: sendTopic)
        default: throw ElementHandlerError.message("Unkown network service: \(serviceStr)")
        }
        
        let conversionStr = attributes.optionalString(for: .conversion) ?? "none"
        let conversion: NetworkConversion
        
        switch conversionStr {
        case "none": conversion = NoneNetworkConversion()
        case "csv":  conversion = CSVNetworkConversion()
        case "json": conversion = JSONNetworkConversion()
        default: throw ElementHandlerError.message("Unkown network conversion: \(conversionStr)")
        }
        
        let interval = try attributes.optionalValue(for: .interval) ?? 0.0

        results.append(NetworkConnectionDescriptor(id: id, privacyURL: privacy, address: address, discovery: discovery, autoConnect: autoConnect, service: service, conversion: conversion, send: sendHandler.results, receive: receiveHandler.results, interval: interval))
    }
}

final class NetworkElementHandler: ResultElementHandler, LookupElementHandler, AttributelessElementHandler {
    var results = [[NetworkConnectionDescriptor]]()

    var childHandlers: [String: ElementHandler]

    private let networkConnectionHandler = NetworkConnectionElementHandler()

    init() {
        childHandlers = ["connection": networkConnectionHandler]
    }

    func endElement(text: String, attributes: AttributeContainer) throws {
        results.append(networkConnectionHandler.results)
    }
}
