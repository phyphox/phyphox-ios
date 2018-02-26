//
//  ExperimentInfoView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

final class ExperimentInfoView: ExperimentViewModule<InfoViewDescriptor> {
    required init(descriptor: InfoViewDescriptor) {
        super.init(descriptor: descriptor)
        label.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.footnote)
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var s = size
        s.width = size.width - 20.0 //A litte margin at the sides looks nicer
        return label.sizeThatFits(s)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        label.frame = bounds
    }
}
