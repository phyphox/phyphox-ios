//
//  ExperimentValueView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

final class ExperimentValueView: ExperimentViewModule<ValueViewDescriptor>, DataBufferObserver {
    required init(descriptor: ValueViewDescriptor) {
        super.init(descriptor: descriptor)
        
        newValueIn()
        
        descriptor.buffer.addObserver(self)
    }
    
    func dataBufferUpdated(buffer: DataBuffer) {
        newValueIn()
    }
    
    func newValueIn() {
        let str = NSMutableAttributedString(string: self.descriptor.localizedLabel.stringByAppendingString(": "), attributes: [NSFontAttributeName : UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline), NSForegroundColorAttributeName : UIColor.blackColor()])
        
        if let last = descriptor.buffer.last {
            let formatter = NSNumberFormatter()
            formatter.numberStyle = (self.descriptor.scientific ? .ScientificStyle : .DecimalStyle)
            formatter.maximumFractionDigits = self.descriptor.precision
            formatter.minimumIntegerDigits = 1
            
            let formatted = formatter.stringFromNumber(NSNumber(double: last*self.descriptor.factor))!
            
            str.appendAttributedString(NSAttributedString(string: String(format: "%@%@", formatted, (self.descriptor.unit != nil ? String(format: " %@", self.descriptor.unit!) : "")), attributes: [NSFontAttributeName : UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote), NSForegroundColorAttributeName : UIColor.blackColor()]))
        }
        else {
            str.appendAttributedString(NSAttributedString(string: "-", attributes: [NSFontAttributeName : UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote), NSForegroundColorAttributeName : UIColor.blackColor()]))
        }
        
        label.attributedText = str
        
        setNeedsLayout()
    }
    
    override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(size.width, label.sizeThatFits(size).height)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let s = label.sizeThatFits(self.bounds.size)
        
        label.frame = CGRectMake((self.bounds.size.width-s.width)/2.0, (self.bounds.size.height-s.height)/2.0, s.width, s.height)
    }
}
