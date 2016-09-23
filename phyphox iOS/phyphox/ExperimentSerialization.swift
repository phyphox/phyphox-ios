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

enum SerializationError: ErrorType {
    case GenericError
    case InvalidExperimentFile
    case InvalidFilePath
    case WriteFailed
    case EmptyData
    case NewExperimentFileVersion
}

let serializationQueue = dispatch_queue_create("de.rwth-aachen.phyphox.serialization", DISPATCH_QUEUE_CONCURRENT)

final class ExperimentSerialization: NSObject {
    /**
     
     */
    class func readExperimentFromFile(path: String) throws -> Experiment {
        let data = NSData(contentsOfFile: path)
        
        if (data != nil && data!.length > 0) {
            return try deserializeExperiment(data!);
        }
        else {
            throw SerializationError.InvalidFilePath
        }
    }
    
    class func readExperimentFromURL(url: NSURL) throws -> Experiment {
        let data = NSData(contentsOfURL: url)
        
        if (data != nil && data!.length > 0) {
            let experiment = try deserializeExperiment(data!);
            experiment.source = url
            experiment.sourceData = data
            return experiment
        }
        else {
            throw SerializationError.InvalidFilePath
        }
    }
    
    class func serializeExperiment(experiment: Experiment) throws -> NSData {
        return try ExperimentSerializer(experiment: experiment).serialize()
    }
    
    class func deserializeExperiment(data: NSData) throws -> Experiment {
        return try ExperimentDeserializer(data: data).deserialize()
    }
    
    class func serializeExperimentAsynchronous(experiment: Experiment, completion: ((data: NSData?, error: SerializationError?) -> Void)) {
        ExperimentSerializer(experiment: experiment).serializeAsynchronous(completion)
    }
    
    class func deserializeExperiment(data: NSData, completion: ((Experiment: Experiment?, error: SerializationError?) -> Void)) {
        ExperimentDeserializer(data: data).deserializeAsynchronous(completion)
    }
    
    class func writeExperimentToFile(experiment: Experiment, path: String) throws -> Bool {
        let data = try serializeExperiment(experiment)
        
        if (data.length > 0) {
            guard data.writeToFile(path, atomically: true) else {
                throw SerializationError.WriteFailed
            }
        }
        
        throw SerializationError.EmptyData
    }
}
