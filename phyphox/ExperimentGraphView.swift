//
//  ExperimentGraphView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

public class ExperimentGraphView: ExperimentViewModule<GraphViewDescriptor> {
    let graph: JGGraphView
    
    typealias T = GraphViewDescriptor
    
    required public init(descriptor: GraphViewDescriptor) {
        graph = JGGraphView()
        graph.path = JGGraphDrawer.drawPath([[0.0, 100.0]], ys: [[0.0, 100.0]], maxX: 100.0, maxY: 100.0, size: CGSizeMake(100.0, 100.0))
        
        super.init(descriptor: descriptor)
        
        backgroundColor = UIColor.redColor()
        addSubview(graph)
    }
    
    public override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(size.width, min(size.width/descriptor.aspectRatio, size.height))
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        graph.frame = self.bounds
        let b = graph.path!.bounds
        
        let scaleX = graph.frame.size.width/b.size.width
        let scaleY = graph.frame.size.height/b.size.height
        
        graph.path!.applyTransform(CGAffineTransformMakeScale(scaleX, scaleY))
        
        graph.refreshPath()
    }
}

