//
//  GraphViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreGraphics

/**
 Represents a graph view.
 */
public final class GraphViewDescriptor: ViewDescriptor {
    let xLabel: String
    let yLabel: String
    
    let logX: Bool
    let logY: Bool
    
    var xInputBuffer: DataBuffer?
    var yInputBuffer: DataBuffer
    
    let aspectRatio: CGFloat
    let partialUpdate: Bool
    let drawDots: Bool
    let forceFullDataset: Bool
    let history: UInt
    
    let numberOfValuesToPlot: Int //0 == all
    
    init(label: String, labelSize: CGFloat, xLabel: String, yLabel: String, xInputBuffer: DataBuffer?, yInputBuffer: DataBuffer, logX: Bool, logY: Bool, aspectRatio: CGFloat, drawDots: Bool, partialUpdate: Bool, forceFullDataset: Bool, history: UInt, numberOfValuesToPlot: Int) {
        self.xLabel = xLabel
        self.yLabel = yLabel
        
        self.logX = logX
        self.logY = logY
        
        self.xInputBuffer = xInputBuffer
        self.yInputBuffer = yInputBuffer
        
        self.aspectRatio = aspectRatio
        self.partialUpdate = partialUpdate
        self.drawDots = drawDots
        self.forceFullDataset = forceFullDataset
        self.history = history
        self.numberOfValuesToPlot = numberOfValuesToPlot
        
        super.init(label: label, labelSize: labelSize)
    }
}
