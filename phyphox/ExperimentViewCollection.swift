//
//  ExperimentViewCollection.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

class ExperimentViewCollection: UIView {
    let modules: [UIView]
    
    init(viewDescriptor: ExperimentViewCollectionDescriptor) {
        var m: [UIView] = []
        
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
    
    override func sizeThatFits(size: CGSize) -> CGSize {
        var currentY: CGFloat = 0.0
        var previousXMax: CGFloat = 0.0
        var highestYInRow: CGFloat = 0.0
        
        var xMax: CGFloat = 0.0
        var yMax: CGFloat = 0.0
        
        for m in modules {
            let s = m.sizeThatFits(size)
            
            let sameY = previousXMax+s.width <= size.width
            
            if !sameY {
                previousXMax = 0.0
                currentY += highestYInRow
            }
            
            highestYInRow = max(highestYInRow, s.height)
            
            xMax = max(previousXMax+s.width, xMax)
            yMax = currentY+highestYInRow
        }
        
        return CGSizeMake(xMax, yMax)
    }
    
    override func layoutSubviews() {
        var currentY: CGFloat = 0.0
        var previousXMax: CGFloat = 0.0
        
        var highestYInRow: CGFloat = 0.0
        
        for m in modules {
            let s = m.sizeThatFits(self.bounds.size)
            
            let sameY = previousXMax+s.width <= self.bounds.size.width
            
            if !sameY {
                previousXMax = 0.0
                currentY += highestYInRow
            }
            
            m.frame = CGRectMake(previousXMax, currentY, s.width, s.height)
            
            highestYInRow = max(highestYInRow, s.height)
        }
    }
}
