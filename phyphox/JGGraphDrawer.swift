//
//  JGGraphDrawer.swift
//  Crono
//
//  Created by Jonas Gessner on 31.03.15.
//  Copyright (c) 2015 Jonas Gessner. All rights reserved.
//

import UIKit

final class JGGraphDrawer {
    
    class func drawImage(xs: [[Double]], ys: [[Double]], minX: Double = 0.0, maxX: Double, minY: Double = 0.0, maxY: Double, size: CGSize, lineWidth: CGFloat = 2.0, color: UIColor) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        
        let path = drawPath(xs, ys: ys, minX: minX, maxX: maxX, minY: minY, maxY: maxY, size: size)
        
        path.lineWidth = lineWidth
        
        color.setStroke()
        
        path.stroke()
        
        let img = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return img
    }
    
    class func drawPath(xs: [[Double]], ys: [[Double]], minX: Double = 0.0, maxX: Double, minY: Double = 0.0, maxY: Double, size: CGSize) -> UIBezierPath {
        let path = UIBezierPath()
        
        for idx in 0..<xs.count {
            let x = xs[idx]
            let y = ys[idx]
            
            var translationRateX = (maxX-minX)/Double(size.width)
            var translationRateY = (maxY-minY)/Double(size.height)
            
            if (!isnormal(translationRateX)) {
                translationRateX = 0.0
            }
            
            if (!isnormal(translationRateY)) {
                translationRateY = 0.0
            }
            
            for i in 0..<x.count {
                let xVal = x[i]
                let yVal = y[i]
                
                var tX = CGFloat(xVal/translationRateX)
                var tY = CGFloat(yVal/translationRateY)
                
                if (!isnormal(tX)) {
                    tX = 0.0
                }
                
                if (!isnormal(tY)) {
                    tY = 0.0
                }
                
                let translatedPoint = CGPointMake(tX, size.height-tY)
                
                if (i == 0) {
                    path.moveToPoint(translatedPoint)
                }
                else {
                    path.addLineToPoint(translatedPoint)
                }
            }
        }
        
        return path
    }
}
