//
//  GraphGridView.swift
//  phyphox
//
//  Created by Jonas Gessner on 24.03.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

protocol GraphGridDelegate: class {
    func updatePlotArea()
}

final class GraphGridView: UIView {
    private let borderView = UIView()
    var delegate: GraphGridDelegate? = nil
    var descriptor: GraphViewDescriptor? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        borderView.layer.borderColor = UIColor(white: 1.0, alpha: 1.0).CGColor
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
    
    var gridLabelSpace: CGPoint = .zero {
        didSet {
            self.delegate?.updatePlotArea()
        }
    }
    
    var insetRect: CGRect {
        return CGRectOffset(CGRectInset(bounds, gridInset.x + gridLabelSpace.x/2.0, gridInset.y + gridLabelSpace.y/2.0), gridOffset.x+gridLabelSpace.x/2.0, gridOffset.y - gridLabelSpace.y/2.0)
    }
    
    convenience init(descriptor: GraphViewDescriptor?) {
        self.init(frame: .zero)
        self.descriptor = descriptor
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        self.init(descriptor: nil)
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
            let defaultFont = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
            label.font = defaultFont.fontWithSize(defaultFont.pointSize * 0.8)
            
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
        let spacing = 1.0/UIScreen.mainScreen().scale
        super.layoutSubviews()
        
        let formatterX = NSNumberFormatter()
        formatterX.usesSignificantDigits = true
        formatterX.minimumSignificantDigits = Int(descriptor?.xPrecision ?? 3)
        
        let formatterY = NSNumberFormatter()
        formatterY.usesSignificantDigits = true
        formatterY.minimumSignificantDigits = Int(descriptor?.yPrecision ?? 3)
        
        func format(n: Double, formatter: NSNumberFormatter) -> String {
            let expThreshold = max(formatter.minimumSignificantDigits, 3)
            if (n == 0 || (abs(n) < pow(10.0, Double(expThreshold)) && abs(n) > pow(10.0, Double(-expThreshold)))) {
                formatter.numberStyle = .DecimalStyle
                return formatter.stringFromNumber(NSNumber(double: n))!
            } else {
                formatter.numberStyle = .ScientificStyle
                return formatter.stringFromNumber(NSNumber(double: n))!
            }
        }
        
        var xSpace = CGFloat(0.0)
        var ySpace = CGFloat(0.0)
        var index = 0
        if grid != nil {
            if grid!.xGridLines != nil {
                for line in grid!.xGridLines! {
                    let label = labels[index]
                    label.textColor = kTextColor
                    
                    label.text = format(line.absoluteValue, formatter: formatterX)
                    label.sizeToFit()
                    
                    ySpace = max(ySpace, label.frame.size.height)
                    
                    index += 1
                }
            }
            if grid!.yGridLines != nil {
                for line in grid!.yGridLines! {
                    let label = labels[index]
                    label.textColor = kTextColor
                    
                    label.text = format(line.absoluteValue, formatter: formatterY)
                    label.sizeToFit()
                    
                    xSpace = max(xSpace, label.frame.size.width)
                    
                    index += 1
                }
            }
        }
        
        gridLabelSpace = CGPoint(x: xSpace, y: ySpace)
        
        borderView.frame = insetRect
        
        if grid != nil {
            index = 0
            
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
                    
                    view.hidden = (origin <= insetRect.origin.x + 2.0 || origin >= insetRect.size.width-2.0) //Hide the line if it is too close the the graph bounds (where fixed lines are shown anyways)
                    
                    view.frame = CGRectMake(origin+insetRect.origin.x, insetRect.origin.y, smallestUnit, insetRect.size.height)
                    
                    let label = labels[index]
                    label.frame = CGRectMake(origin+insetRect.origin.x-label.frame.size.width/2.0, CGRectGetMaxY(insetRect)+spacing, label.frame.size.width, label.frame.size.height)
                    
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
                    
                    view.hidden = (origin <= insetRect.origin.y + 2.0 || origin >= insetRect.size.height-2.0) //Hide the line if it is too close the the graph bounds (where fixed lines are shown anyways)
                    
                    view.frame = CGRectMake(insetRect.origin.x, origin+insetRect.origin.y, insetRect.size.width, smallestUnit)
                    
                    let label = labels[index]
                    label.frame = CGRectMake(insetRect.origin.x-spacing-label.frame.size.width, origin+insetRect.origin.y-label.frame.size.height/2.0, label.frame.size.width, label.frame.size.height)
                    
                    index += 1
                }
            }
        }
    }
}
