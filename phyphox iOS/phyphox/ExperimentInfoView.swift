//
//  ExperimentInfoView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

public final class ExperimentInfoView: ExperimentViewModule<InfoViewDescriptor> {
    required public init(descriptor: InfoViewDescriptor) {
        super.init(descriptor: descriptor)
    }
    
    public override func sizeThatFits(size: CGSize) -> CGSize {
        return label.sizeThatFits(size)
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        label.frame = self.bounds
    }
}
