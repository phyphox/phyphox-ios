//
//  ExperimentDeserializer.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentDeserializer: NSObject {
    private var data: NSData
    
    init(data: NSData) {
        self.data = data
        super.init()
    }
    
    func deserialize() throws -> Experiment {
        throw SerializationError.GenericError
    }
    
    func deserializeAsynchronous(completion: (experiment: Experiment?, error: SerializationError?) -> Void) {
        dispatch_async(serializationQueue) { () -> Void in
            do {
                let experiment = try self.deserialize()
                
                completion(experiment: experiment, error: nil)
            }
            catch {
                completion(experiment: nil, error: error as? SerializationError)
            }
        }
    }
}
