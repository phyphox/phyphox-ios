//
//  ExperimentViewModule.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

protocol ExperimentViewModuleProtocol {
    func update()
}

public class ExperimentViewModule<T:ViewDescriptor>: UIView, ExperimentViewModuleProtocol {
    weak var descriptor: T!
    
    let label: UILabel
    
    required public init(descriptor: T) {
        label = UILabel()
        label.numberOfLines = 0
        
        label.text = descriptor.label
        
        let baseFont = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        
        label.font = baseFont.fontWithSize(baseFont.pointSize*descriptor.labelSize)
        
        self.descriptor = descriptor
        
        super.init(frame: CGRect.zero)
        
        addSubview(label)
    }
    
    func update() {
        
    }
    
    @available(*, unavailable)
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

