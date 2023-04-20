//
//  UIImageExt.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 06.03.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation


extension UIImage {
    // Resize image to a given size
    func resize(size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resizedImage
    }
}

