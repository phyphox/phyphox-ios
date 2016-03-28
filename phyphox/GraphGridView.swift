//
//  GraphGridView.swift
//  phyphox
//
//  Created by Jonas Gessner on 24.03.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

final class GraphGridView: UIView {
    private let borderView = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        borderView.layer.borderColor = UIColor(white: 0.0, alpha: 0.5).CGColor
        borderView.layer.borderWidth = 1.0/UIScreen.mainScreen().scale
        
        addSubview(borderView)
    }
    
    var gridInsets: CGPoint = .zero {
        didSet {
            setNeedsLayout()
        }
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
    }
    
    var grid: GraphGrid? {
        didSet {
            updateLineViews()
            setNeedsLayout()
        }
    }
    
    private var lineViews: [GraphGridLineView] = []
    
    private func updateLineViews() {
        var neededViews = 0
        if grid != nil {
            if grid!.xGridLines != nil {
                neededViews += grid!.xGridLines!.count
            }
            
            if grid!.yGridLines != nil {
                neededViews += grid!.yGridLines!.count
            }
        }
        
        let delta = lineViews.count-neededViews
        
        if delta > 0 {
            var index = 0
            
            lineViews = lineViews.filter({ (view) -> Bool in
                if index < neededViews {
                    index += 1
                    return true
                }
                else {
                    view.removeFromSuperview()
                    return false
                }
            })
        }
        else if delta < 0 {
            for _ in delta..<0 {
                let view = GraphGridLineView()
                
                addSubview(view)
                
                lineViews.append(view)
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let insetRect = CGRectInset(self.bounds, gridInsets.x, gridInsets.y)
        
        let add = 2.0/UIScreen.mainScreen().scale
        
        borderView.frame = CGRectInset(self.bounds, gridInsets.x-add, gridInsets.y-add)
        
        if grid != nil {
            var index = 0
            
            let smallestUnit = 1.0/UIScreen.mainScreen().scale
            
            if grid!.xGridLines != nil {
                for line in grid!.xGridLines! {
                    let view = lineViews[index]
                    
                    view.horizontal = false
                    
                    let origin = insetRect.size.width*line.relativeValue
                    
                    view.alpha = (origin > 2.0 && origin < insetRect.size.width-2.0 ? 1.0 : 0.0) //Hide the line if it is too close the the graph bounds (where fixed lines are shown anyways)
                    
                    view.frame = CGRectMake(origin+insetRect.origin.x, insetRect.origin.y, smallestUnit, insetRect.size.height)
                    
                    index += 1
                }
            }
            
            if grid!.yGridLines != nil {
                for line in grid!.yGridLines! {
                    let view = lineViews[index]
                    
                    view.horizontal = true
                    
                    let origin = insetRect.size.height*line.relativeValue
                    
                    view.alpha = (origin > 2.0 && origin < insetRect.size.height-2.0 ? 1.0 : 0.0) //Hide the line if it is too close the the graph bounds (where fixed lines are shown anyways)
                    
                    view.frame = CGRectMake(insetRect.origin.x, origin+insetRect.origin.y, insetRect.size.width, smallestUnit)
                    
                    index += 1
                }
            }
        }
    }
}
