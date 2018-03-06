//
//  ExperimentDataContainersParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

final class ExperimentDataContainersParser: ExperimentMetadataParser {
    var containers: [AnyObject]?

    required init(_ data: NSDictionary) {
        containers = getElementsWithKey(data, key: "container")
    }

    enum ExperimentDataContainerType {
        case buffer
        case unknown
    }

    func dataContainerTypeFromXML(_ xml: [String: AnyObject]?, key: String) throws -> ExperimentDataContainerType {
        let str = stringFromXML(xml, key: key, defaultValue: "buffer")

        if str == "buffer" {
            return .buffer
        }
        else {
            throw SerializationError.invalidExperimentFile(message: "Invalid data container type: \(str)")
        }
    }

    func parse(analysisInputBufferNames: Set<String>, experimentPeristentStorageURL: URL) throws -> [String: DataBuffer] {
        guard let cont = containers else { return [:] }

        var buffers: [String: DataBuffer] = [:]

        for container in cont {
            var name: String!

            var containerType = ExperimentDataContainerType.buffer //Default
            var bufferSize = 1 //Default
            var stat = false //Default

            var baseContents: [Double] = []

            if let str = container as? String {
                name = str
            }
            else if let dict = container as? NSDictionary {
                if let attributes = dict[XMLDictionaryAttributesKey] as? [String: String] {
                    bufferSize = intTypeFromXML(attributes as [String : AnyObject], key: "size", defaultValue: 1)
                    stat = boolFromXML(attributes as [String : AnyObject], key: "static", defaultValue: false)
                    let initText = stringFromXML(attributes as [String : AnyObject], key: "init", defaultValue: "")
                    baseContents = initText.components(separatedBy: ",").flatMap{Double($0.trimmingCharacters(in: .whitespaces))}

                    containerType = try dataContainerTypeFromXML(attributes as [String : AnyObject], key: "type")
                }

                name = dict[XMLDictionaryTextKey] as! String
            }

            if containerType == .buffer && name.count > 0 {
                let storageType: DataBuffer.StorageType

                if bufferSize == 0 && !analysisInputBufferNames.contains(name) {
                    let bufferURL = experimentPeristentStorageURL.appendingPathComponent(name).appendingPathExtension(bufferContentsFileExtension)

                    storageType = .hybrid(memorySize: 5000, persistentStorageLocation: bufferURL)
                }
                else {
                    storageType = .memory(size: bufferSize)
                }

                let buffer = DataBuffer(name: name, storage: storageType, baseContents: baseContents, static: stat)

                buffers[name] = buffer
            }
        }

        return buffers
    }
}
