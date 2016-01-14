//
//  ExperimentViewCollectionDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreGraphics

/**
 Represents an experiment view, which contais zero or more graph views, represented by graph descriptors.
 */
public final class ExperimentViewCollectionDescriptor: ViewDescriptor {
    let graphViews: [GraphViewDescriptor]?
    let infoViews: [InfoViewDescriptor]?
    let editViews: [EditViewDescriptor]?
    let valueViews: [ValueViewDescriptor]?
    
    init(label: String, labelSize: CGFloat, graphViews: [GraphViewDescriptor]?, infoViews: [InfoViewDescriptor]?, editViews: [EditViewDescriptor]?, valueViews: [ValueViewDescriptor]?) {
        self.graphViews = graphViews
        self.infoViews = infoViews
        self.editViews = editViews
        self.valueViews = valueViews
        
        super.init(label: label, labelSize: labelSize)
    }
}
