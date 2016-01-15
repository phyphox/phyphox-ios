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

final class JGGraphView: UIView {
    
    override class func layerClass() -> AnyClass {
        return CAShapeLayer.self
    }
    
    var path: UIBezierPath? {
        didSet {
            if path == nil {
                (self.layer as! CAShapeLayer).path = nil
            }
            else {
                (self.layer as! CAShapeLayer).path = path!.CGPath
            }
        }
    }
    
    func refreshPath() {
        if path != nil {
            (self.layer as! CAShapeLayer).path = path!.CGPath
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let layer = (self.layer as! CAShapeLayer)
        
        layer.strokeColor = UIColor.blackColor().CGColor
        
        layer.lineWidth = 1.0
        layer.lineJoin = kCALineJoinRound
        layer.lineCap = kCALineCapRound
        
        layer.fillColor = UIColor.clearColor().CGColor
//        layer.fillRule = kCAFillRuleEvenOdd
//        layer.fillMode = kCAFillModeRemoved
    }

    @available(*, unavailable)
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
