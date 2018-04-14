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
    static let parser = XMLElementParser(rootHandler: ExperimentFileHandler())

    static func readExperimentFromURL(_ url: URL) throws -> Experiment {
        if url.pathExtension == experimentStateFileExtension {
            let data = try Data(contentsOf: url.appendingPathComponent(experimentStateExperimentFileName).appendingPathExtension(experimentFileExtension))
            let experiment = try deserializeExperiment(data)
            experiment.local = url.isFileURL
            experiment.source = url

            return experiment
        }

        let data = try Data(contentsOf: url)
        let experiment = try deserializeExperiment(data)
        experiment.local = url.isFileURL
        experiment.source = url

        return experiment
    }

    private static func deserializeExperiment(_ data: Data) throws -> Experiment {
        return try parser.parse(data: data)
    }
}
