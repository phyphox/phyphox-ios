//
//  SeparatorViewDescriptor.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 09.02.17.
//  Copyright © 2017 RWTH Aachen. All rights reserved.
//

import Foundation

struct SeparatorViewDescriptor: ViewDescriptor, Equatable {
    let color: UIColor
    let height: CGFloat

    let label = ""
    var visibilityBuffer: DataBuffer?
    let translation: ExperimentTranslationCollection? = nil

    init(height: CGFloat, color: UIColor, visibilityBuffer: DataBuffer?) {
        self.color = color
        self.height = height
        self.visibilityBuffer = visibilityBuffer
    }
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        return "<div style=\"font-size:105%; background: #\(color.hexStringValue!); height: \(height)em \" class=\"separatorElement adjustableColor\" id=\"element\(id)\"><p>\(localizedLabel)</p></div>"
    }
}
