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
final class ExperimentViewDescriptor: ViewDescriptor {
    let graphs: [GraphViewDescriptor]?
    
    init(label: String, graphs: [GraphViewDescriptor]?, labelSize: Double) {
        self.graphs = graphs
        
        super.init(label: label, labelSize: labelSize)
    }
}
