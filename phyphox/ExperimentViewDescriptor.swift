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
    let graphViews: [GraphViewDescriptor]?
    let editViews: [EditViewDescriptor]?
    let valueViews: [ValueViewDescriptor]?
    
    init(label: String, labelSize: Double, graphViews: [GraphViewDescriptor]?, editViews: [EditViewDescriptor]?, valueViews: [ValueViewDescriptor]?) {
        self.graphViews = graphViews
        self.editViews = editViews
        self.valueViews = valueViews
        
        super.init(label: label, labelSize: labelSize)
    }
}
