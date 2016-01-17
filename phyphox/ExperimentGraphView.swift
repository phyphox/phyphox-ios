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
    //    let imgView: UIImageView
    
    var queue: dispatch_queue_t!
    
    typealias T = GraphViewDescriptor
    
    required public init(descriptor: GraphViewDescriptor) {
        graph = JGGraphView()
        
        //        imgView = UIImageView()
        
        super.init(descriptor: descriptor)
        
        addSubview(graph)
        //        addSubview(imgView)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "setNeedsUpdate", name: DataBufferReceivedNewValueNotification, object: descriptor.yInputBuffer)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    private var lastIndexXArray: [Double]?
    private var lastCount: Int?
    private var lastXRange: Double?
    private var lastYRange: Double?
    //    private lazy var path: UIBezierPath = UIBezierPath()
    
    private var lastCut: Int = 0
    
    override func update() {
        dispatch_async(queue) { () -> Void in
            autoreleasepool({ () -> () in
                var xValues: JGGraphValueSource
                let yValues = self.descriptor.yInputBuffer.graphValueSource
                
                let minY = self.descriptor.yInputBuffer.min
                let maxY = self.descriptor.yInputBuffer.max
                
                var count = yValues.count
                
                if let xBuf = self.descriptor.xInputBuffer {
                    xValues = xBuf.graphValueSource
                    
                    count = min(xValues.count, count)
                }
                else {
                    var xC = 0
                    
                    if self.lastIndexXArray != nil {
                        xC = self.lastIndexXArray!.count
                    }
                    
                    let delta = count-xC
                    
                    if delta > 0 && self.lastIndexXArray == nil {
                        self.lastIndexXArray = []
                    }
                    
                    for i in xC..<count {
                        self.lastIndexXArray!.append(Double(i))
                    }
                    
                    xValues = JGGraphFixedValueSource(array: self.lastIndexXArray!)
                }
                
                let cut = (self.descriptor.numberOfValuesToPlot > 0 ? max(0, count-self.descriptor.numberOfValuesToPlot) : 0)
                
                if count > 1 {
                    if self.lastCount == nil || count > self.lastCount! || cut > 0 {
                        let maxX = xValues.last!
                        let minX = xValues[cut]
                        
                        //                    let xRange = maxX-minX
                        //                    let yRange = maxY!-minY!
                        
                        //                    if self.lastCount != nil {
                        //                        let scaleX = CGFloat(self.lastXRange!/xRange)
                        //                        let scaleY = CGFloat(self.lastYRange!/yRange)
                        //
                        //                        if isnormal(scaleX) && isnormal(scaleY) {
                        //                            self.path.applyTransform(CGAffineTransformMakeScale(scaleX, scaleY))
                        //                        }
                        //                    }
                        //
                        //                    if cut > 0 {
                        //                        let cutXrange = xValues[cut]-xValues[lastCut]
                        //
                        //                        lastCut = cut
                        //
                        //                        self.path.applyTransform(CGAffineTransformMakeTranslation(-CGFloat(cutXrange/self.lastXRange!)*self.path.bounds.size.widt, 0.0))
                        //                    }
                        
                        let path = JGGraphDrawer.drawPath(xValues, ys: yValues, minX: minX, maxX: maxX, logX: self.descriptor.logX, minY: minY!, maxY: maxY!, logY: self.descriptor.logY, count: count, size: self.graph.bounds.size, start: cut)
                        
                        //                    self.lastXRange = xRange
                        //                    self.lastYRange = yRange
                        //
                        //                    self.lastCount = count
                        
                        dispatch_sync(dispatch_get_main_queue(), { () -> Void in
                            self.graph.path = path
                        })
                    }
                }
                else {
                    dispatch_sync(dispatch_get_main_queue(), { () -> Void in
                        self.graph.path = nil
                    })
                }
            })
        }
    }
    
    public override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(size.width, min(size.width/descriptor.aspectRatio, size.height))
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        graph.frame = self.bounds
        //        imgView.frame = self.bounds
    }
}

