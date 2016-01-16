//
//  JGGraphDrawer.swift
//  Crono
//
//  Created by Jonas Gessner on 31.03.15.
//  Copyright (c) 2015 Jonas Gessner. All rights reserved.
//

/**
This code is taken from the Crono iOS app (https://itunes.apple.com/app/id980940387). © 2015-2016 Jonas Gessner
*/

import UIKit

final class JGGraphDrawer {
    
//    class func drawImage(xs: [[Double]], ys: [[Double]], minX: Double = 0.0, maxX: Double, minY: Double = 0.0, maxY: Double, size: CGSize, lineWidth: CGFloat = 2.0, color: UIColor) -> UIImage {
//        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
//        
//        let path = drawPath(xs, ys: ys, minX: minX, maxX: maxX, minY: minY, maxY: maxY, size: size)
//        
//        path.lineWidth = lineWidth
//        
//        color.setStroke()
//        
//        path.stroke()
//        
//        let img = UIGraphicsGetImageFromCurrentImageContext()
//        
//        UIGraphicsEndImageContext()
//        
//        return img
//    }
    
    class func drawPathToImage(path: UIBezierPath, size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        
        UIColor.blackColor().setStroke()
        path.stroke()
        
        let img = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return img
    }
    
    class func drawPath(xs: [Double], ys: [Double], minX: Double = 0.0, maxX: Double, minY: Double = 0.0, maxY: Double, count: Int, size: CGSize, reusePath: UIBezierPath? = nil, lastIndex: Int? = nil) -> UIBezierPath {
        let path = (reusePath != nil ? reusePath! : UIBezierPath())
        let startIndex = (lastIndex != nil ? lastIndex! : 0)
        
        if startIndex >= count {
            print("Da fuck man")
            return path
        }
        
        var translationRateX = (maxX-minX)/Double(size.width)
        var translationRateY = (maxY-minY)/Double(size.height)
        
        if (!isnormal(translationRateX)) {
            translationRateX = 1.0
        }
        
        if (!isnormal(translationRateY)) {
            translationRateY = 1.0
        }
        
        for idx in startIndex..<count {
            let x = xs[idx]
            let y = ys[idx]
            

//            for i in 0..<x.count {
                let xVal = x//x[i]
                let yVal = y-minY//y[i]-minY
                
                var tX = CGFloat(xVal/translationRateX)
                var tY = CGFloat(yVal/translationRateY)
                
                if (!isnormal(tX)) {
                    tX = 0.0
                }
                
                if (!isnormal(tY)) {
                    tY = 0.0
                }
                
                let translatedPoint = CGPointMake(tX, size.height-tY)
                
                if (path.empty) {
                    path.moveToPoint(translatedPoint)
                }
                else {
                    path.addLineToPoint(translatedPoint)
                }
//            }
        }
        
        return path
    }
}
