//
//  GraphViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

/**
 Represents a graph view.
 */
final class GraphViewDescriptor {
    let label: String
    
    let xLabel: String
    let yLabel: String
    
    let partialUpdate: Bool
    
    weak var xInputBuffer: DataBuffer?
    weak var yInputBuffer: DataBuffer?
    
    
    init(label: String, xLabel: String, yLabel: String, partialUpdate: Bool, xInputBuffer: DataBuffer?, yInputBuffer: DataBuffer?) {
        self.label = label
        
        self.xLabel = xLabel
        self.yLabel = yLabel
        
        self.partialUpdate = partialUpdate
        
        self.xInputBuffer = xInputBuffer
        self.yInputBuffer = yInputBuffer
    }
}
