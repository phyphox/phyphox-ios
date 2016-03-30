//
//  ExperimentViewModule.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

protocol ExperimentViewModuleProtocol {
    func setNeedsUpdate()
}

public class ExperimentViewModule<T:ViewDescriptor>: UIView, ExperimentViewModuleProtocol {
    weak var descriptor: T!
    
    let label: UILabel
    
    required public init(descriptor: T) {
        label = UILabel()
        label.numberOfLines = 0
        
        label.text = descriptor.localizedLabel
        
        label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote)
        
        self.descriptor = descriptor
        
        super.init(frame: CGRect.zero)
        
        addSubview(label)
    }
    
    private var updateScheduled: Bool = false
    
    func setNeedsUpdate() {
        if !updateScheduled {
            updateScheduled = true
            
            //60fps max
            after(1.0/60.0, closure: { () -> Void in
                self.update()
                self.updateScheduled = false
            })
        }
    }
    
    internal func update() {
        
    }
    
    @available(*, unavailable)
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

