//
//  ExperimentValueView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

public class ExperimentValueView: ExperimentViewModule<ValueViewDescriptor> {
    required public init(descriptor: ValueViewDescriptor) {
        super.init(descriptor: descriptor)
        
        let str = NSMutableAttributedString(string: descriptor.label.stringByAppendingString(": "), attributes: [NSFontAttributeName : UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline), NSForegroundColorAttributeName : UIColor.blackColor()])
        
        if let last = descriptor.buffer.last {
            if descriptor.scientific {
                str.appendAttributedString(NSAttributedString(string: String(format: "%.%ie%@", descriptor.precision, last, (descriptor.unit != nil ? String(format: " %@", descriptor.unit!) : "")), attributes: [NSFontAttributeName : UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote), NSForegroundColorAttributeName : UIColor.blackColor()]))
            }
            else {
                str.appendAttributedString(NSAttributedString(string: String(format: "%.%if%@", descriptor.precision, last, (descriptor.unit != nil ? String(format: " %@", descriptor.unit!) : "")), attributes: [NSFontAttributeName : UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote), NSForegroundColorAttributeName : UIColor.blackColor()]))
            }
        }
        else {
            str.appendAttributedString(NSAttributedString(string: "-", attributes: [NSFontAttributeName : UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote), NSForegroundColorAttributeName : UIColor.blackColor()]))
        }
        
        label.attributedText = str
    }
    
    public override func sizeThatFits(size: CGSize) -> CGSize {
        return label.sizeThatFits(size)
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        label.frame = self.bounds
    }
}
