//
//  ExperimentGraphView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

let q = dispatch_queue_create("queue", DISPATCH_QUEUE_SERIAL)

public class ExperimentGraphView: ExperimentViewModule<GraphViewDescriptor> {
    let graph: JGGraphView
    let imgView: UIImageView
    
    typealias T = GraphViewDescriptor
    
    required public init(descriptor: GraphViewDescriptor) {
        graph = JGGraphView()
//        graph.path = JGGraphDrawer.drawPath([[0.0, 100.0]], ys: [[0.0, 100.0]], maxX: 100.0, maxY: 100.0, size: CGSizeMake(100.0, 100.0))
//      
        imgView = UIImageView()
        
        super.init(descriptor: descriptor)
        
        backgroundColor = UIColor.redColor()
        addSubview(graph)
        addSubview(imgView)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "update", name: DataBufferReceivedNewValueNotification, object: descriptor.yInputBuffer)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    private var lastIndexXArray: [Double]?
    private var lastCount: Int?
    private var lastXRange: Double?
    private var lastYRange: Double?
    private lazy var path: UIBezierPath = UIBezierPath()
    private var lastImage: UIImage?
    
    override func update() {
        var xValues: [Double]
        let yValues: [Double] = descriptor.yInputBuffer.toArray()
        
        let minY = descriptor.yInputBuffer.min
        let maxY = descriptor.yInputBuffer.max
        
        var count = yValues.count
        
        if let xBuf = descriptor.xInputBuffer {
            xValues = xBuf.toArray()
            
            count = min(xValues.count, count)
        }
        else {
            var xC = 0
            
            if lastIndexXArray != nil {
                xC = lastIndexXArray!.count
            }
            
            let delta = count-xC
            
            if delta > 0 && lastIndexXArray == nil {
                lastIndexXArray = []
            }
            
            for i in xC..<count {
                lastIndexXArray!.append(Double(i))
            }
            
            xValues = lastIndexXArray!
        }
        

        
//        if let xBuf = descriptor.xInputBuffer {
//            for (i, value) in xBuf.enumerate() {
//                if i < descriptor.yInputBuffer.count {
//                    if let v = descriptor.yInputBuffer.queue.objectAtIndex(i) { // Thread safe get
//                        minY = min(minY, v)
//                        maxY = max(maxY, v)
//                        
//                        xValues.append(value)
//                        yValues.append(v)
//                    }
//                    else {
//                        break
//                    }
//                }
//                else {
//                    break
//                }
//            }
//        }
//        else {
//            for (i, value) in descriptor.yInputBuffer.enumerate() {
//                minY = min(minY, value)
//                maxY = max(maxY, value)
//                
//                xValues.append(Double(i))
//                yValues.append(value)
//            }
//        }
        
        dispatch_async(q, { () -> Void in
            if count > 1 {
                if self.lastCount == nil || count > self.lastCount! {
                    let maxX = xValues.last!
                    let minX = xValues.first!
                    
                    let xRange = maxX-minX
                    let yRange = maxY!-minY!
                    
//                    let abschnitt: UIImage
                    
                    if self.lastImage != nil {
                        let scaleX = CGFloat(self.lastXRange!/xRange)
                        let scaleY = CGFloat(self.lastYRange!/yRange)
                        
//                        if isnormal(scaleX) && isnormal(scaleY) {
//                            self.path.applyTransform(CGAffineTransformMakeScale(scaleX, scaleY))
//                        }
                        
                        let rangeDeltaX = xRange-self.lastXRange!
//                        let rangeDeltaY = yRange-self.lastYRange!
                        
                        let width = self.bounds.size.width*CGFloat(rangeDeltaX/xRange)
                            
                        let newPath = JGGraphDrawer.drawPath(xValues, ys: yValues, minX: minX, maxX: maxX, minY: minY!, maxY: maxY!, count: count, size: CGSizeMake(width, self.bounds.size.height), lastIndex: self.lastCount!-1)
                        
                        let oldImgSize = self.lastImage!.size
                        
                        let newImgSize = CGSizeMake(oldImgSize.width*scaleX, oldImgSize.height*scaleY)
                        
                        UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, 0.0)
                        
                        self.lastImage!.drawInRect(CGRectMake(0.0, (oldImgSize.height-newImgSize.height)/2.0, newImgSize.width, newImgSize.height))
                        
                        newPath.applyTransform(CGAffineTransformMakeTranslation(newImgSize.width, 0.0))
                        
                        newPath.lineWidth = 2.0
                        UIColor.blackColor().setStroke()
                        newPath.stroke()
                        
                        self.lastImage = UIGraphicsGetImageFromCurrentImageContext()
                        
                        UIGraphicsEndImageContext()
                    }
                    else {
                        let newPath = JGGraphDrawer.drawPath(xValues, ys: yValues, minX: minX, maxX: maxX, minY: minY!, maxY: maxY!, count: count, size: self.bounds.size)
                        
                        UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, 0.0)
                        
                        newPath.lineWidth = 2.0
                        UIColor.blackColor().setStroke()
                        newPath.stroke()
                        
                        self.lastImage = UIGraphicsGetImageFromCurrentImageContext()
                        
                        UIGraphicsEndImageContext()
                    }
                    
//                    self.path = JGGraphDrawer.drawPath(xValues, ys: yValues, minX: minX, maxX: maxX, minY: minY!, maxY: maxY!, count: count, size: self.graph.bounds.size, reusePath: self.path, lastIndex: self.lastCount)
//                    
                    self.lastXRange = xRange
                    self.lastYRange = yRange
                    
                    self.lastCount = count
//
//                    self.path.lineWidth = 2.0
//                    UIColor.blackColor().setStroke()
//                    
//                    let img = JGGraphDrawer.drawPathToImage(self.path, size: self.bounds.size)
//                    
                    
                    dispatch_sync(dispatch_get_main_queue(), { () -> Void in
//                        self.graph.path = self.path
                        self.imgView.image = self.lastImage!
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
    
    public override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(size.width, min(size.width/descriptor.aspectRatio, size.height))
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        graph.frame = self.bounds
        imgView.frame = self.bounds
//        if graph.path != nil {
//
//            let b = graph.path!.bounds
//            
//            let scaleX = graph.frame.size.width/b.size.width
//            let scaleY = graph.frame.size.height/b.size.height
//            
//            graph.path!.applyTransform(CGAffineTransformMakeScale(scaleX, scaleY))
//            
//            graph.refreshPath()
//        }
    }
}

