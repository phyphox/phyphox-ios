//
//  ExperimentSerializer.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentSerializer: NSObject {
    private var experiment: Experiment
    
    init(experiment: Experiment) {
        self.experiment = experiment
        super.init()
    }
    
    func serialize() throws -> NSData {
        throw SerializationError.GenericError
    }
    
    func serializeAsynchronous(completion: (data: NSData?, error: SerializationError?) -> Void) {
        dispatch_async(serializationQueue) { () -> Void in
            do {
                let data = try self.serialize()
                
                completion(data: data, error: nil)
            }
            catch {
                completion(data: nil, error: error as? SerializationError)
            }
        }
    }
}
