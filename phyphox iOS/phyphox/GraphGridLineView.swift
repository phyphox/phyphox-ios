//
//  GraphGridLineView.swift
//  phyphox
//
//  Created by Jonas Gessner on 25.03.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

private final class GraphGridLineLayer: CAShapeLayer {
    override init() {
        super.init()
        
        commonInit()
    }
    
    override init(layer: AnyObject) {
        super.init(layer: layer)
        
        commonInit()
    }
    
    func commonInit() {
        lineDashPattern = [NSNumber(double: 6.0), NSNumber(double: 5.0)]
        lineCap = kCALineCapRound
        
        strokeColor = UIColor(white: 1.0, alpha: 0.3).CGColor
        fillColor = UIColor.clearColor().CGColor
        backgroundColor = UIColor.clearColor().CGColor
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var horizontal: Bool = false {
        didSet {
            setNeedsLayout()
        }
    }
    
    private override func layoutSublayers() {
        super.layoutSublayers()
        
        lineWidth = (horizontal ? bounds.size.height : bounds.size.width)

        let path = CGPathCreateMutable()
        
        let beginPoint = CGPoint(x: (horizontal ? 0.0 : bounds.size.width/2.0), y: (horizontal ? bounds.size.height/2.0 : 0.0))
        let endPoint = CGPoint(x: (horizontal ? bounds.size.width : bounds.size.width/2.0), y: (horizontal ? bounds.size.height/2.0 : bounds.size.height))
        
        CGPathMoveToPoint(path, nil, beginPoint.x, beginPoint.y)
        CGPathAddLineToPoint(path, nil, endPoint.x, endPoint.y)
        
        self.path = path
    }
}

final class GraphGridLineView: UIView {
    private var gridLayer: GraphGridLineLayer {
        get {
            return self.layer as! GraphGridLineLayer
        }
    }
    
    var horizontal: Bool {
        set {
            if newValue != gridLayer.horizontal {
                gridLayer.horizontal = newValue
            }
        }
        get {
            return gridLayer.horizontal
        }
    }
    
    override class func layerClass() -> AnyClass {
        return GraphGridLineLayer.self
    }
}
