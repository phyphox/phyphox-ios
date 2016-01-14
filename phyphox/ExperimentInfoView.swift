//
//  ExperimentInfoView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

public class ExperimentInfoView: ExperimentViewModule<InfoViewDescriptor> {
    let label: UILabel
    
    override init(descriptor: InfoViewDescriptor) {
        label = UILabel()
        label.numberOfLines = 0
        
        label.text = descriptor.label
        
        let baseFont = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        
        label.font = baseFont.fontWithSize(baseFont.pointSize*descriptor.labelSize)
        
        super.init(descriptor: descriptor)
        
        addSubview(label)
    }
    
    public override func sizeThatFits(size: CGSize) -> CGSize {
        return label.sizeThatFits(size)
    }
    
    override public func layoutSubviews() {
        label.frame = self.bounds
    }
}
