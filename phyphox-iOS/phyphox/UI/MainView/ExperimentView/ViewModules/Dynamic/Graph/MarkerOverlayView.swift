//
//  MarkerOverlay.swift
//  phyphox
//
//  Created by Sebastian Staacks on 15.05.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import UIKit

final class MarkerOverlayView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
    }
    
    var markers: [(x: CGFloat, y: CGFloat)]? {
        didSet {
            updateOverlay()
        }
    }
    
    var showMarkers: Bool = true
    
    private var markerLayers: [CAShapeLayer] = []
    private var lineLayers: [CAShapeLayer] = []
    
    private func updateOverlay() {
        
        func makeCircle(rx: CGFloat, ry: CGFloat) -> UIBezierPath {
            let x = rx * bounds.width
            let y = ry * bounds.height
            let r: CGFloat = 6.0
            let rect = CGRect(x: x-r, y: y-r, width: 2*r+1, height: 2*r+1)
            return UIBezierPath(ovalIn: rect)
        }
        
        func makeLine(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat) -> UIBezierPath {
            let line = UIBezierPath()
            line.move(to: CGPoint(x: x1 * bounds.width, y: y1 * bounds.height))
            line.addLine(to: CGPoint(x: x2 * bounds.width, y: y2 * bounds.height))
            line.close()
            return line
        }
        
        func makeLayer(path: CGPath) -> CAShapeLayer {
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = path
            shapeLayer.fillColor = UIColor.clear.cgColor
            shapeLayer.strokeColor = UIColor.white.cgColor
            shapeLayer.lineWidth = 1.0
            return shapeLayer
        }
        
        for i in (0..<max(markers?.count ?? 0, markerLayers.count)).reversed() {
            if (!showMarkers && i < markerLayers.count) || i >= markers?.count ?? 0 {
                markerLayers[i].removeFromSuperlayer()
                markerLayers.remove(at: i)
            } else if i >= markerLayers.count {
                let newCircle = makeCircle(rx: markers![i].x, ry: markers![i].y)
                let newLayer = makeLayer(path: newCircle.cgPath)
                layer.addSublayer(newLayer)
                markerLayers.append(newLayer)
            } else {
                let newCircle = makeCircle(rx: markers![i].x, ry: markers![i].y)
                markerLayers[i].path = newCircle.cgPath
            }
        }
        
        for i in (0..<max((markers?.count ?? 0)-1, lineLayers.count)).reversed() {
            if i >= (markers?.count ?? 0)-1 {
                lineLayers[i].removeFromSuperlayer()
                lineLayers.remove(at: i)
            } else if i >= lineLayers.count {
                let newLine = makeLine(x1: markers![i].x, y1: markers![i].y, x2: markers![i+1].x, y2: markers![i+1].y)
                let newLayer = makeLayer(path: newLine.cgPath)
                layer.addSublayer(newLayer)
                lineLayers.append(newLayer)
            } else {
                let newLine = makeLine(x1: markers![i].x, y1: markers![i].y, x2: markers![i+1].x, y2: markers![i+1].y)
                lineLayers[i].path = newLine.cgPath
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
}
