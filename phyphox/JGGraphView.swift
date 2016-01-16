//
//  JGGraphView.swift
//  Crono
//
//  Created by Jonas Gessner on 01.04.15.
//  Copyright (c) 2015 Jonas Gessner. All rights reserved.
//

/**
This code is taken from the Crono iOS app (https://itunes.apple.com/app/id980940387). © 2015-2016 Jonas Gessner
*/

import UIKit

final class JGGraphLayer: CALayer {
//    weak var path: CGPathRef? {
//        didSet {
//            setNeedsDisplay()
//        }
//    }
//    
//    var c = 0
//    
//    override func drawInContext(ctx: CGContext) {
//        if c > 100 {
//            print("End counting")
//            return
//        }
//        if path != nil {
//            CGContextSetStrokeColorWithColor(ctx, UIColor.redColor().CGColor);
//            CGContextBeginPath(ctx)
//            CGContextAddPath(ctx, path)
//            CGContextStrokePath(ctx)
//        }
//        
//        c++
//    }
}

final class JGGraphView: UIView {
    let graphLayer: JGGraphLayer
    
//    override class func layerClass() -> AnyClass {
//        return JGGraphLayer.self
    //    }
    
    var path: UIBezierPath? {
        set {
            drawer.path = newValue
            graphLayer.setNeedsDisplay()
        }
        
        get {
            return drawer.path
        }
        //        didSet {
        ////            if path == nil {
        ////                (self.layer as! JGGraphLayer).path = nil
        ////            }
        ////            else {
        ////                (self.layer as! JGGraphLayer).path = path!.CGPath
        ////            }
        //
        //            setNeedsDisplay()
        //        }
    }
    
    func refreshPath() {
        graphLayer.setNeedsDisplay()
//        if path != nil {
//            (self.layer as! JGGraphLayer).path = path!.CGPath
//        }
    }
    
//    let graphLayer: CALayer
    
    class Drawer: NSObject {
        weak var path: UIBezierPath?
        
        override func drawLayer(layer: CALayer, inContext ctx: CGContext) {
            if path != nil {
                CGContextSetStrokeColorWithColor(ctx, UIColor.whiteColor().CGColor);
                CGContextAddPath(ctx, self.path!.CGPath)
                CGContextStrokePath(ctx)
            }
        }
    }
    
    let drawer: Drawer
    
    override init(frame: CGRect) {
        drawer = Drawer()
        
        graphLayer = JGGraphLayer()
        graphLayer.backgroundColor = UIColor.clearColor().CGColor
        graphLayer.delegate = drawer
        graphLayer.drawsAsynchronously = true
        
        super.init(frame: frame)
        
        layer.addSublayer(graphLayer)
//
//        let layer = (self.layer as! JGGraphLayer)
        
//        layer.strokeColor = UIColor.blackColor().CGColor
//        
//        layer.lineWidth = 1.0
//        layer.lineJoin = kCALineJoinRound
//        layer.lineCap = kCALineCapRound
//        
//        layer.fillColor = UIColor.clearColor().CGColor
        
        
//        layer.fillRule = kCAFillRuleEvenOdd
//        layer.fillMode = kCAFillModeRemoved
        
//
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        graphLayer.frame = self.layer.bounds
    }

    @available(*, unavailable)
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
