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
    var childLayer: CALayer? {
        willSet {
            if newValue != childLayer {
                childLayer?.removeFromSuperlayer()
            }
        }
        
        didSet {
            if childLayer != nil {
                addSublayer(childLayer!)
            }
        }
    }
    
    override func layoutSublayers() {
        super.layoutSublayers()
        childLayer?.frame = self.bounds
    }
}

final class JGGraphView: UIView {
    override class func layerClass() -> AnyClass {
        return JGGraphLayer.self
    }
    
    private let drawer: Drawer
    
    private class Drawer: NSObject {
        var path: UIBezierPath?
        
        override func drawLayer(layer: CALayer, inContext ctx: CGContext) {
            if path != nil {
//                let s = CFAbsoluteTimeGetCurrent()
                CGContextSetStrokeColorWithColor(ctx, UIColor.blackColor().CGColor);
                CGContextAddPath(ctx, self.path!.CGPath)
                CGContextSetLineJoin(ctx, .Round)
                CGContextSetLineCap(ctx, .Round)
                CGContextStrokePath(ctx)
//                print("Draw took \(CFAbsoluteTimeGetCurrent()-s)")
            }
        }
    }
    
    override init(frame: CGRect) {
        drawer = Drawer()
        
        let graphLayer = CALayer()
        graphLayer.contentsScale = UIScreen.mainScreen().scale
        graphLayer.backgroundColor = UIColor.clearColor().CGColor
        graphLayer.delegate = drawer
        graphLayer.drawsAsynchronously = true
        
        super.init(frame: frame)
        
        (layer as! JGGraphLayer).childLayer = graphLayer
    }
    
    var path: UIBezierPath? {
        set {
            drawer.path = newValue
            refreshPath()
        }
        
        get {
            return drawer.path
        }
    }
    
    private var imageView: UIImageView?
    
    var image: UIImage? {
        didSet {
            if image == nil {
                imageView?.removeFromSuperview()
                imageView = nil
            }
            else {
                if imageView == nil {
                    imageView = UIImageView(image: image)
                    addSubview(imageView!)
                }
                else {
                    imageView!.image = image
                }
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        imageView?.frame = self.bounds
    }
    
    func refreshPath() {
        (self.layer as! JGGraphLayer).childLayer!.setNeedsDisplay()
    }

    @available(*, unavailable)
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
