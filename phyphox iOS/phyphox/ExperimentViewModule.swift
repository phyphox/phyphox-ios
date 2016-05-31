//
//  ExperimentViewModule.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

protocol ExperimentViewModuleProtocol {
    func setNeedsUpdate()
    func unregisterFromBuffer()
    var active: Bool { get set}
}

public class ExperimentViewModule<T:ViewDescriptor>: UIView, ExperimentViewModuleProtocol {
    weak var descriptor: T!
    
    let label: UILabel
    var active = false
    
    required public init(descriptor: T) {
        label = UILabel()
        label.numberOfLines = 0
        
        label.text = descriptor.localizedLabel
        
        label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote)
        label.textColor = kTextColor
        
        self.descriptor = descriptor
        
        super.init(frame: CGRect.zero)
        
        addSubview(label)
    }
    
    func unregisterFromBuffer() {
        
    }
    
    private var updateScheduled: Bool = false
    
    func setNeedsUpdate() {
        if active && !updateScheduled {
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

