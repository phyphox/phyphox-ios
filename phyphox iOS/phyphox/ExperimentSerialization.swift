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

let serializationQueue = DispatchQueue(label: "de.rwth-aachen.phyphox.serialization", attributes: DispatchQueue.Attributes.concurrent)

final class ExperimentSerialization: NSObject {
    /**
     
     */
    class func readExperimentFromFile(_ path: String) throws -> Experiment {
        let data = try? Data(contentsOf: URL(fileURLWithPath: path))
        
        if (data != nil && data!.count > 0) {
            let experiment = try deserializeExperiment(data!);
            experiment.source = nil
            experiment.sourceData = data
            return experiment
        }
        else {
            throw SerializationError.invalidFilePath
        }
    }
    
    class func readExperimentFromURL(_ url: URL) throws -> Experiment {
        let data = try? Data(contentsOf: url)
        
        if (data != nil && data!.count > 0) {
            let experiment = try deserializeExperiment(data!);
            experiment.source = url
            experiment.sourceData = data
            return experiment
        }
        else {
            throw SerializationError.invalidFilePath
        }
    }
    
    class func serializeExperiment(_ experiment: Experiment) throws -> Data {
        return try ExperimentSerializer(experiment: experiment).serialize() as Data
    }
    
    class func deserializeExperiment(_ data: Data) throws -> Experiment {
        return try ExperimentDeserializer(data: data).deserialize()
    }
    
    class func serializeExperimentAsynchronous(_ experiment: Experiment, completion: @escaping ((_ data: Data?, _ error: SerializationError?) -> Void)) {
        ExperimentSerializer(experiment: experiment).serializeAsynchronous(completion)
    }
    
    class func deserializeExperiment(_ data: Data, completion: @escaping ((_ Experiment: Experiment?, _ error: SerializationError?) -> Void)) {
        ExperimentDeserializer(data: data).deserializeAsynchronous(completion)
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
