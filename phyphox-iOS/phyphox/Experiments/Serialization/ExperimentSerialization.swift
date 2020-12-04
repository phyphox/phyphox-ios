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

extension SerializationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .genericError(let message):
            return message
        case .invalidExperimentFile(let message):
            return "Invalid experiment file: \(message)"
        case .invalidFilePath:
            return "Invalid file path."
        case .writeFailed:
            return "Write failed."
        case .emptyData:
            return "Empty data."
        case .newExperimentFileVersion(let phyphoxFormat, let fileFormat):
            return "New phyphox file format \(fileFormat) found. Your phyphox version supports up to \(phyphoxFormat) and might be outdated."
        }
    }
}

let experimentStateFileExtension = "phystate"
let bufferContentsFileExtension = "buffer"
let experimentStateExperimentFileName = "Experiment"
let experimentFileExtension = "phyphox"

final class ExperimentSerialization {
    static let parser = DocumentParser(documentHandler: PhyphoxDocumentHandler())

    static func readExperimentFromURL(_ url: URL) throws -> Experiment {
        let readURL: URL

        if url.pathExtension == experimentStateFileExtension {
            readURL = url.appendingPathComponent(experimentStateExperimentFileName).appendingPathExtension(experimentFileExtension)
        }
        else {
            readURL = url
        }

        guard let inputStream = InputStream(url: readURL) else {
            throw SerializationError.invalidFilePath
        }
        let crc32Stream = CRC32InputStream(inputStream)
        let experiment = try parser.parse(stream: crc32Stream)
        experiment.source = url
        experiment.crc32 = crc32Stream.crcValue

        return experiment
    }
}
