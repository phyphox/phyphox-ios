//
//  ExperimentViewCollection.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

class ExperimentViewCollection: UIView {
    let modules: [ExperimentViewBaseModule]
    
    init(viewDescriptor: ExperimentViewDescriptor) {
        var m: [ExperimentViewBaseModule] = []
        
        if viewDescriptor.editViews != nil {
            for descriptor in viewDescriptor.editViews! {
                m.append(ExperimentEditView(descriptor: descriptor))
            }
        }
        
        if viewDescriptor.infoViews != nil {
            for descriptor in viewDescriptor.infoViews! {
                m.append(ExperimentInfoView(descriptor: descriptor))
            }
        }
        
        if viewDescriptor.graphViews != nil {
            for descriptor in viewDescriptor.graphViews! {
                m.append(ExperimentGraphView(descriptor: descriptor))
            }
        }
        
        if viewDescriptor.valueViews != nil {
            for descriptor in viewDescriptor.valueViews! {
                m.append(ExperimentValueView(descriptor: descriptor))
            }
        }
        
        assert(m.count > 0, "No view descriptors")
        
        modules = m
        
        super.init(frame: CGRect.zero)
        
        for module in modules {
            addSubview(module)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
