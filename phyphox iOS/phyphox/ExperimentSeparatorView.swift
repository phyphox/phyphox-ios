//
//  ExperimentSeparatorView.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 09.02.17.
//  Copyright © 2017 RWTH Aachen. All rights reserved.
//

import Foundation

import UIKit

final class ExperimentSeparatorView: ExperimentViewModule<SeparatorViewDescriptor> {
    required init(descriptor: SeparatorViewDescriptor) {
        super.init(descriptor: descriptor)
        self.backgroundColor = descriptor.color
        label.hidden = true
    }
    
    override func sizeThatFits(size: CGSize) -> CGSize {
        var s = size
        s.height = descriptor.height * label.font!.pointSize
        return s
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
}
