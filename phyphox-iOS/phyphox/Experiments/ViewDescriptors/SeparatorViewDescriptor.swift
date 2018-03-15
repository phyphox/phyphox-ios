//
//  SeparatorViewDescriptor.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 09.02.17.
//  Copyright © 2017 RWTH Aachen. All rights reserved.
//

import Foundation

final class SeparatorViewDescriptor: ViewDescriptor {
    
    let color: UIColor
    let height: CGFloat
    
    init(height: CGFloat, color: UIColor) {
        self.color = color
        self.height = height
        super.init(label: "", translation: nil)
    }
    
    override func generateViewHTMLWithID(_ id: Int) -> String {
        return "<div style=\"font-size:105%; background: #\(color.hexStringValue!); height: \(height)em \" class=\"separatorElement\" id=\"element\(id)\"><p>\(localizedLabel)</p></div>"
    }
}
