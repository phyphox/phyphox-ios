//
//  ExperimentSerialization.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

//http://phyphox.com/wiki/index.php?title=Phyphox_file_format

import Foundation

enum SerializationError: Error {
    case genericError(message: String)
    case invalidExperimentFile(message: String)
    case invalidFilePath
    case writeFailed
    case emptyData
    case newExperimentFileVersion(phyphoxFormat: String, fileFormat: String)
}

let experimentStateFileExtension = "phystate"
let bufferContentsFileExtension = "buffer"
let experimentStateExperimentFileName = "Experiment"
let experimentFileExtension = "phyphox"

final class ExperimentSerialization {
    static let parser = XMLDocumentParser(documentHandler: PhyphoxDocumentHandler())

    static func readExperimentFromURL(_ url: URL, legacy: Bool = false) throws -> Experiment {
        let readURL: URL

        if url.pathExtension == experimentStateFileExtension {
            readURL = url.appendingPathComponent(experimentStateExperimentFileName).appendingPathExtension(experimentFileExtension)
        }
        else {
            readURL = url
        }

        guard let stream = InputStream(url: readURL) else {
            throw SerializationError.invalidFilePath
        }

        let experiment = legacy ? try ExperimentDeserializer(stream: stream).deserialize() : try parser.parse(stream: stream)
        experiment.local = url.isFileURL
        experiment.source = url

        return experiment
    }
}
