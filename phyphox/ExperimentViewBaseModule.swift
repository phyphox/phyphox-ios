//
//  ExperimentViewBaseModule.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

class ExperimentViewBaseModule: UIView, ExperimentViewModule {
    typealias In = ViewDescriptor
    
    let descriptor: In
    
    required init(descriptor: In) {
        self.descriptor = descriptor
        
        super.init(frame: CGRect.zero)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

