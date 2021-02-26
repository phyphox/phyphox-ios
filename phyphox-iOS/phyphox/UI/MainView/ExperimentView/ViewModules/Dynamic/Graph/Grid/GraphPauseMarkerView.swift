//
//  GraphPauseMarkerView.swift
//  phyphox
//
//  Created by Sebastian Staacks on 18.12.20.
//  Copyright © 2020 RWTH Aachen. All rights reserved.
//

import UIKit

private final class GraphPauseMarkerLayer: CAShapeLayer {
    override init() {
        super.init()
        
        commonInit()
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
        
        commonInit()
    }
    
    func commonInit() {
        strokeColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.6).cgColor
        fillColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.2).cgColor
        backgroundColor = UIColor.clear.cgColor
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSublayers() {
        super.layoutSublayers()

        let path = CGMutablePath(rect: bounds, transform: nil)
     
        self.path = path
    }
}

final class GraphPauseMarkerView: UIView {
    private var pauseMarkerLayer: GraphPauseMarkerLayer {
        get {
            return self.layer as! GraphPauseMarkerLayer
        }
    }
    
    override class var layerClass : AnyClass {
        return GraphPauseMarkerLayer.self
    }
}
