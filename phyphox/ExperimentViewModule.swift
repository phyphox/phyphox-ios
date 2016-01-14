//
//  ExperimentViewModule.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

public class ExperimentViewModule<T:ViewDescriptor>: UIView {
    weak var descriptor: T!
    
    init(descriptor: T) {
        self.descriptor = descriptor
        
        super.init(frame: CGRect.zero)
    }
    
    func setUp() {
        fatalError("Subclasses of ExperimentViewModule must override method")
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

