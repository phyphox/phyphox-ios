//
//  ExperimentSerialization.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
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

let serializationQueue = DispatchQueue(label: "de.rwth-aachen.phyphox.serialization", attributes: DispatchQueue.Attributes.concurrent)

final class ExperimentSerialization: NSObject {
    class func readExperimentFromFile(_ path: String) throws -> Experiment {
        return try readExperimentFromURL(URL(fileURLWithPath: path))
    }
    
    class func readExperimentFromURL(_ url: URL) throws -> Experiment {
        if url.pathExtension == experimentStateFileExtension {
            let data = try Data(contentsOf: url.appendingPathComponent("Experiment.phyphox"))
            let experiment = try deserializeExperiment(data, local: url.isFileURL)
            experiment.source = url

            try experiment.buffers.0?.forEach { name, buffer in
                let bufferURL = url.appendingPathComponent(name).appendingPathExtension("buffer")
                if FileManager.default.fileExists(atPath: bufferURL.path) {
                    try buffer.readState(from: bufferURL)
                }
            }

            return experiment
        }
        else if let data = try? Data(contentsOf: url) {
            let experiment = try deserializeExperiment(data, local: url.isFileURL)
            experiment.source = url

            return experiment
        }

        throw SerializationError.invalidFilePath
    }
    
    private class func serializeExperiment(_ experiment: Experiment) throws -> Data {
        return try ExperimentSerializer(experiment: experiment).serialize() as Data
    }

    private class func deserializeExperiment(_ data: Data, local: Bool) throws -> Experiment {
        return try ExperimentDeserializer(data: data, local: local).deserialize()
    }
    
    private class func serializeExperimentAsynchronous(_ experiment: Experiment, completion: @escaping ((_ data: Data?, _ error: SerializationError?) -> Void)) {
        ExperimentSerializer(experiment: experiment).serializeAsynchronous(completion)
    }
    
    private class func deserializeExperiment(_ data: Data, local: Bool, completion: @escaping ((_ Experiment: Experiment?, _ error: SerializationError?) -> Void)) {
        ExperimentDeserializer(data: data, local: local).deserializeAsynchronous(completion)
    }
    
    class func writeExperimentToFile(_ experiment: Experiment, path: String) throws -> Bool {
        let data = try serializeExperiment(experiment)
        
        if (data.count > 0) {
            guard (try? data.write(to: URL(fileURLWithPath: path), options: [.atomic])) != nil else {
                throw SerializationError.writeFailed
            }
        }
        
        throw SerializationError.emptyData
    }
}
