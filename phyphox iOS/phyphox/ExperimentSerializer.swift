//
//  ExperimentSerializer.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

final class ExperimentSerializer: NSObject {
    fileprivate var experiment: Experiment
    
    init(experiment: Experiment) {
        self.experiment = experiment
        super.init()
    }
    
    func serialize() throws -> Data {
        throw SerializationError.genericError(message: "Serializer not implemented.")
    }
    
    func serializeAsynchronous(_ completion: @escaping (_ data: Data?, _ error: SerializationError?) -> Void) {
        serializationQueue.async { () -> Void in
            do {
                let data = try self.serialize()
                
                completion(data, nil)
            }
            catch {
                completion(nil, error as? SerializationError)
            }
        }
    }
}
