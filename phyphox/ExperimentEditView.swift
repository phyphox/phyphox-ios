//
//  ExperimentEditView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

private let spacing: CGFloat = 5.0
private let textFieldWidth: CGFloat = 60.0

public class ExperimentEditView: ExperimentViewModule<EditViewDescriptor> {
    let textField: UITextField
    let unitLabel: UILabel?
    
    required public init(descriptor: EditViewDescriptor) {
        textField = UITextField()
        textField.text = (descriptor.decimal ? String(Int(descriptor.defaultValue)) : String(descriptor.defaultValue))
        textField.borderStyle = .RoundedRect
        
        if descriptor.unit != nil {
            unitLabel = {
                let l = UILabel()
                l.text = descriptor.unit
                
                let baseFont = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
                
                l.font = baseFont.fontWithSize(baseFont.pointSize*descriptor.labelSize)
                
                return l
            }()
        }
        else {
            unitLabel = nil
        }
        
        super.init(descriptor: descriptor)
        
        addSubview(textField)
        if unitLabel != nil {
            addSubview(unitLabel!)
        }
    }
    
    public override func sizeThatFits(size: CGSize) -> CGSize {
        let s1 = label.sizeThatFits(size)
        var s2 = textField.sizeThatFits(size)
        s2.width = textFieldWidth
        
        var width = s1.width+spacing+textFieldWidth
        var height = max(s1.height, s2.height)
        
        if unitLabel != nil {
            let s3 = unitLabel!.sizeThatFits(size)
            width += (spacing+s3.width)*2.0
            height = max(height, s3.height)
        }
        
        return CGSize(width: width, height: height)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        let s1 = label.sizeThatFits(self.bounds.size)
        var s2 = textField.sizeThatFits(self.bounds.size)
        s2.width = textFieldWidth
        
        let width = s1.width+spacing+s2.width
        
        label.frame = CGRect(origin: CGPoint(x: (self.bounds.size.width-width)/2.0, y: (self.bounds.size.height-s1.height)/2.0), size: s1)
        textField.frame = CGRect(origin: CGPoint(x: CGRectGetMaxX(label.frame)+spacing, y: (self.bounds.size.height-s2.height)/2.0), size: s2)
        
        if unitLabel != nil {
            let s3 = unitLabel!.sizeThatFits(self.bounds.size)
            unitLabel!.frame = CGRect(origin: CGPoint(x: CGRectGetMaxX(textField.frame)+spacing, y: (self.bounds.size.height-s3.height)/2.0), size: s3)
        }
    }
}
