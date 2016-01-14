//
//  ExperimentGraphView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

let kGraphHeight: CGFloat = 100.0

public class ExperimentGraphView: ExperimentViewModule<GraphViewDescriptor> {
    let graph: JGGraphView
    
    override init(descriptor: GraphViewDescriptor) {
        graph = JGGraphView()
        
        super.init(descriptor: descriptor)
        
        backgroundColor = UIColor.blackColor()
        addSubview(graph)
    }
    
    public override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(size.width, min(kGraphHeight, size.height))
    }
    
    public override func layoutSubviews() {
        graph.frame = self.bounds
    }
}

