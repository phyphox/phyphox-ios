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
    
    var queue: dispatch_queue_t! {
        didSet {
            NSLog("set queue (is nil: %@) on cell %p", (queue == nil ? "yes" : "no") , self)
        }
    }
    
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
    
    private var hasUpdateBlockEnqueued = false
    
    override func update() {
        if hasUpdateBlockEnqueued || superview == nil {
            return
        }
        
        hasUpdateBlockEnqueued = true
        
        dispatch_async(queue) { () -> Void in
            autoreleasepool({ () -> () in
                var xValues: JGGraphValueSource
                let yValues = self.descriptor.yInputBuffer.graphValueSource
                
                let minY = self.descriptor.yInputBuffer.min
                let maxY = self.descriptor.yInputBuffer.max
                
                var trashedCount = self.descriptor.yInputBuffer.trashedCount
                
                var count = yValues.count
                
                if let xBuf = self.descriptor.xInputBuffer {
                    xValues = xBuf.graphValueSource
                    
                    count = min(xValues.count, count)
                    trashedCount = min(xBuf.trashedCount, trashedCount)
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
                
                if count > 1 {
//                    if self.lastCount == nil || count > self.lastCount!-trashedCount {
                        let maxX = xValues.last!
                        let minX = xValues[0]
                        
//                        let start = (self.lastCount == nil ? 0 : self.lastCount!-trashedCount)
//                        
//                        let xRange = maxX-minX
//                        let yRange = maxY!-minY!
//                        
//                        if self.lastCount != nil {
//                            let scaleX = CGFloat(self.lastXRange!/xRange)
//                            let scaleY = CGFloat(self.lastYRange!/yRange)
//                            
//                            if isnormal(scaleX) && isnormal(scaleY) {
//                                self.path.applyTransform(CGAffineTransformMakeScale(scaleX, scaleY))
//                            }
//                        }
                        
                        let s = CFAbsoluteTimeGetCurrent()
//                        let img = JGGraphDrawer.drawBitmap(xValues, ys: yValues, minX: minX, maxX: maxX, logX: self.descriptor.logX, minY: minY!, maxY: maxY!, logY: self.descriptor.logY, count: count, size: self.graph.bounds.size, averaging: self.descriptor.forceFullDataset)!
                        
                        var newMaxY: Double? = nil
                        var newMinY: Double? = nil
                        
                        let path = JGGraphDrawer.drawPath(xValues, ys: yValues, minX: minX, maxX: maxX, logX: self.descriptor.logX, minY: minY!, maxY: maxY!, logY: self.descriptor.logY, count: count, size: self.graph.graphSize, /*reusePath: self.path, start: start,*/ averaging: self.descriptor.forceFullDataset, newMinY: &newMinY, newMaxY: &newMaxY)
                        
                        print("Path took \(CFAbsoluteTimeGetCurrent()-s)")
                        
                        self.descriptor.yInputBuffer.updateMaxAndMin(newMaxY, min: newMinY)
                        
//                        self.lastCount = count
                    
//                        self.lastXRange = xRange
//                        self.lastYRange = yRange
                        
                        dispatch_sync(dispatch_get_main_queue(), { () -> Void in
//                            self.graph.image = img
                            self.graph.path = path
                        })
//                    }
                }
                else {
                    dispatch_sync(dispatch_get_main_queue(), { () -> Void in
                        self.graph.path = nil
                    })
                }
            })
            
            self.hasUpdateBlockEnqueued = false
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

