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
    func registerInputBuffer(_ buffer: DataBuffer)
    var active: Bool { get set }
}

typealias ExperimentViewModuleView = ExperimentViewModuleProtocol & UIView

class ExperimentViewModule<T: ViewDescriptor>: UIView, ExperimentViewModuleProtocol {
    weak var descriptor: T!
    
    let label: UILabel
    var active = false {
        didSet {
            if active {
                setNeedsUpdate()
            }
        }
    }
    
    var delegate: ModuleExclusiveViewDelegate? = nil

    required public init(descriptor: T) {
        label = UILabel()
        label.numberOfLines = 0
        
        label.text = descriptor.localizedLabel

        label.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
        label.textColor = kTextColor
        
        self.descriptor = descriptor
        
        super.init(frame: CGRect.zero)
        
        addSubview(label)
    }

    func registerInputBuffer(_ buffer: DataBuffer) {
        buffer.addObserver(self)
    }
    
    private var updateScheduled: Bool = false
    
    func setNeedsUpdate() {
        if active && !updateScheduled {
            updateScheduled = true
            triggerUpdate()
        }
    }
    
    private func triggerUpdate() {
        if updateScheduled {
            //60fps max
            after(1.0/60.0, closure: { () -> Void in
                self.update()
                self.updateScheduled = false
            })
        }
    }
    
    func update() {
        
    }
    
    @available(*, unavailable)
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ExperimentViewModule: DataBufferObserver {
    func dataBufferUpdated(_ buffer: DataBuffer, noData: Bool) {
        setNeedsUpdate()
    }
}
