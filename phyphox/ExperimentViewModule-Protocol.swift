//
//  ExperimentViewModule-Protocol.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

protocol ExperimentViewModule {
    typealias In
    
    var descriptor: In { get }
    
    init(descriptor: In)
}
