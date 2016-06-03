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
    func triggerUpdate()
    func unregisterFromBuffer()
    var active: Bool { get set}
}

public class ExperimentViewModule<T:ViewDescriptor>: UIView, ExperimentViewModuleProtocol {
    weak var descriptor: T!
    
    let label: UILabel
    var active = false
    
    var requiresAnalysis = false
    
    required public init(descriptor: T) {
        label = UILabel()
        label.numberOfLines = 0
        
        label.text = descriptor.localizedLabel
        
        requiresAnalysis = descriptor.requiresAnalysis
        
        label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
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
            
            //We do not want to actually update the view just now if the result depends on any analysis. There are two reasons for this:
            // 1. A buffer may be updated multiple times during analysis if it is used for intermediate results
            // 2. A view (i.e. graph view) may depend on multiple buffers which are not updated simultaneously, possible leading to multiple, unneccessary updates
            if !requiresAnalysis {
                triggerUpdate()
            }
        }
    }
    
    func triggerUpdate() {
        if updateScheduled {
            //60fps max
            after(1.0/60.0, closure: { () -> Void in
                self.update()
                self.updateScheduled = false
            })
        }
    }
    
    func analysisComplete() {
        triggerUpdate()
    }
    
    internal func update() {
        
    }
    
    @available(*, unavailable)
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

