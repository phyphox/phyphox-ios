//
//  GraphGridLineView.swift
//  phyphox
//
//  Created by Jonas Gessner on 25.03.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit

private final class GraphGridLineLayer: CAShapeLayer {
    override init() {
        super.init()
        
        commonInit()
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
        
        commonInit()
    }
    
    func commonInit() {
        lineDashPattern = [NSNumber(value: 6.0 as Double), NSNumber(value: 5.0 as Double)]
        lineCap = CAShapeLayerLineCap.round
        
        strokeColor = UIColor(white: 1.0, alpha: 0.3).cgColor
        fillColor = UIColor.clear.cgColor
        backgroundColor = UIColor.clear.cgColor
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
    
    override func layoutSublayers() {
        super.layoutSublayers()
        
        lineWidth = (horizontal ? bounds.size.height : bounds.size.width)

        let path = CGMutablePath()
        
        let beginPoint = CGPoint(x: (horizontal ? 0.0 : bounds.size.width/2.0), y: (horizontal ? bounds.size.height/2.0 : 0.0))
        let endPoint = CGPoint(x: (horizontal ? bounds.size.width : bounds.size.width/2.0), y: (horizontal ? bounds.size.height/2.0 : bounds.size.height))
        
        path.move(to: beginPoint)
        path.addLine(to: endPoint)
        
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
    
    override class var layerClass : AnyClass {
        return GraphGridLineLayer.self
    }
}
