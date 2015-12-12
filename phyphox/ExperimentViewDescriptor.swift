//
//  ExperimentViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

/**
 Represents an experiment view, which contais zero or more graph views, represented by graph descriptors.
 */
final class ExperimentViewDescriptor {
    let name: String
    
    let graphs: [GraphViewDescriptor]?
    
    init(name: String, graphs: [GraphViewDescriptor]?) {
        self.name = name
        self.graphs = graphs
    }
}
