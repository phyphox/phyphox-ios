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
    
    var gridInset: CGPoint = .zero {
        didSet {
            setNeedsLayout()
        }
    }
    
    var gridOffset: CGPoint = .zero {
        didSet {
            setNeedsLayout()
        }
    }
    
    var insetRect: CGRect {
        return CGRectOffset(CGRectInset(bounds, gridInset.x, gridInset.y), gridOffset.x, gridOffset.y)
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
    private var labels: [UILabel] = []
    
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
        
        func makeLabel() -> UILabel {
            let label = UILabel()
            label.font = UIFont.systemFontOfSize(9.0)
            
            addSubview(label)
            
            return label
        }
        
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
            
            index = 0
            
            labels = labels.filter({ (view) -> Bool in
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
                
                labels.append(makeLabel())
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let insetRect = self.insetRect
        
        let add = 2.0/UIScreen.mainScreen().scale
        
        borderView.frame = CGRectInset(insetRect, -add, -add)
        
        let formatter = NSNumberFormatter()
        formatter.maximumFractionDigits = 3
        formatter.minimumIntegerDigits = 1
        
        func format(n: Double) -> String {
            return formatter.stringFromNumber(NSNumber(double: n))!
        }
        
        if grid != nil {
            var index = 0
            
            let smallestUnit = 1.0/UIScreen.mainScreen().scale
            
            if grid!.xGridLines != nil {
                for line in grid!.xGridLines! {
                    let view = lineViews[index]
                    
                    view.horizontal = false
                    
                    let origin = insetRect.size.width*line.relativeValue
                    
                    if !isfinite(origin) {
                        view.hidden = true
                        continue
                    }
                    
                    view.hidden = (origin <= 2.0 || origin >= insetRect.size.width-2.0) //Hide the line if it is too close the the graph bounds (where fixed lines are shown anyways)
                    
                    view.frame = CGRectMake(origin+insetRect.origin.x, insetRect.origin.y, smallestUnit, insetRect.size.height)
                    
                    let label = labels[index]
                    
                    label.text = format(line.absoluteValue)
                    label.sizeToFit()
                    
                    label.frame = CGRectMake(origin+insetRect.origin.x-label.frame.size.width/2.0, CGRectGetMaxY(insetRect)+2.0, label.frame.size.width, label.frame.size.height)
                    
                    index += 1
                }
            }
            
            if grid!.yGridLines != nil {
                for line in grid!.yGridLines! {
                    let view = lineViews[index]
                    
                    view.horizontal = true
                    
                    let origin = insetRect.size.height-insetRect.size.height*line.relativeValue
                    
                    if !isfinite(origin) {
                       view.hidden = true
                        continue
                    }
                    
                    view.hidden = (origin <= 2.0 || origin >= insetRect.size.height-2.0) //Hide the line if it is too close the the graph bounds (where fixed lines are shown anyways)
                    
                    view.frame = CGRectMake(insetRect.origin.x, origin+insetRect.origin.y, insetRect.size.width, smallestUnit)
                    
                    let label = labels[index]
                    
                    label.text = format(line.absoluteValue)
                    label.sizeToFit()
                    
                    label.frame = CGRectMake(CGRectGetMaxX(insetRect)+3.0, origin+insetRect.origin.y-label.frame.size.height/2.0, label.frame.size.width, label.frame.size.height)
                    
                    index += 1
                }
            }
        }
    }
}
