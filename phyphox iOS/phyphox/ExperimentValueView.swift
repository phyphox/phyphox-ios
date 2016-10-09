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
    let unitLabel: UILabel = UILabel()
    let spacing = CGFloat(10.0)
    
    required init(descriptor: ValueViewDescriptor) {
        super.init(descriptor: descriptor)
        
        self.valueLabel.text = "-"
        self.valueLabel.textColor = kTextColor
        let defaultFont = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        self.valueLabel.font = UIFont.init(descriptor: defaultFont.fontDescriptor(), size: CGFloat(descriptor.size)*defaultFont.pointSize)
        self.valueLabel.textAlignment = NSTextAlignment.Left
        
        self.unitLabel.text = descriptor.unit
        self.unitLabel.textColor = kTextColor
        self.unitLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        self.unitLabel.textAlignment = NSTextAlignment.Left
        
        addSubview(self.valueLabel)
        addSubview(self.unitLabel)
        
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
            
            str = formatter.stringFromNumber(NSNumber(double: last*self.descriptor.factor))! + " "
        }
        else {
            str = "- "
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
        let s3 = unitLabel.sizeThatFits(self.bounds.size)
        
        //We want to align the gap between label and value to the center of the screen. But if the value and unit would exceed the screen, we have to push everything to the left
        let hangOver = (self.bounds.size.width-spacing)/2.0 - s2.width - s3.width - spacing
        let push = hangOver < 0 ? hangOver : 0.0
        
        label.frame = CGRectMake(push, (self.bounds.size.height-s1.height)/2.0, (self.bounds.size.width-spacing)/2.0, s1.height)
        
        valueLabel.frame = CGRectMake(push + (self.bounds.size.width+spacing)/2.0, (self.bounds.size.height-s2.height)/2.0, s2.width, s2.height)
        unitLabel.frame = CGRectMake(valueLabel.frame.maxX, (self.bounds.size.height-s3.height)/2.0, s3.width, s3.height)
        
    }
}
