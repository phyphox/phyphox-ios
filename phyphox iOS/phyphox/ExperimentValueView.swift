//
//  ExperimentValueView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

final class ExperimentValueView: ExperimentViewModule<ValueViewDescriptor>, DataBufferObserver {
    let valueLabel: UILabel = UILabel()
    let spacing = CGFloat(10.0)
    
    required init(descriptor: ValueViewDescriptor) {
        super.init(descriptor: descriptor)
        
        self.valueLabel.text = "-"
        self.valueLabel.textColor = kTextColor
        self.valueLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        self.valueLabel.textAlignment = NSTextAlignment.Left
        
        addSubview(self.valueLabel)
        
        label.textAlignment = NSTextAlignment.Right
        
        newValueIn()
        
        descriptor.buffer.addObserver(self)
    }
    
    override func unregisterFromBuffer() {
        descriptor.buffer.removeObserver(self)
    }
    
    func dataBufferUpdated(buffer: DataBuffer, noData: Bool) {
        newValueIn()
    }
    
    func newValueIn() {
        let str: String
        if let last = descriptor.buffer.last {
            let formatter = NSNumberFormatter()
            formatter.numberStyle = (self.descriptor.scientific ? .ScientificStyle : .DecimalStyle)
            formatter.maximumFractionDigits = self.descriptor.precision
            formatter.minimumIntegerDigits = 1
            
            let formatted = formatter.stringFromNumber(NSNumber(double: last*self.descriptor.factor))!
            
            str = formatted + (self.descriptor.unit == nil ? "" : " " + self.descriptor.unit!)
        }
        else {
            str = "-"
        }
        
        valueLabel.text = str
        
        setNeedsLayout()
    }
    
    override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(size.width, valueLabel.sizeThatFits(size).height)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let s1 = label.sizeThatFits(self.bounds.size)
        let s2 = valueLabel.sizeThatFits(self.bounds.size)
        
        label.frame = CGRectMake(0, (self.bounds.size.height-s1.height)/2.0, (self.bounds.size.width-spacing)/2.0, s1.height)
        valueLabel.frame = CGRectMake((self.bounds.size.width+spacing)/2.0, (self.bounds.size.height-s2.height)/2.0, (self.bounds.size.width-spacing)/2.0, s2.height)
    }
}
