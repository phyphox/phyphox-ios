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
        let defaultFont = UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)
        self.valueLabel.font = UIFont.init(descriptor: defaultFont.fontDescriptor, size: CGFloat(descriptor.size)*defaultFont.pointSize)
        self.valueLabel.textAlignment = NSTextAlignment.left
        
        self.unitLabel.text = descriptor.localizedUnit
        self.unitLabel.textColor = kTextColor
        self.unitLabel.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)
        self.unitLabel.textAlignment = NSTextAlignment.left
        
        addSubview(self.valueLabel)
        addSubview(self.unitLabel)
        
        label.textAlignment = NSTextAlignment.right
        
        newValueIn()
        
        descriptor.buffer.addObserver(self)
    }
    
    override func unregisterFromBuffer() {
        descriptor.buffer.removeObserver(self)
    }
    
    func dataBufferUpdated(_ buffer: DataBuffer, noData: Bool) {
        newValueIn()
    }
    
    func newValueIn() {
        var str: String = ""
        var mapped = false
        let last = descriptor.buffer.last
        if last != nil && !last!.isNaN {
            for mapping in descriptor.mappings {
                if last! >= mapping.min && last! <= mapping.max {
                    str = mapping.str
                    self.unitLabel.text = ""
                    mapped = true
                    break;
                }
            }
            
            if !mapped {
                self.unitLabel.text = descriptor.unit
                
                let formatter = NumberFormatter()
                formatter.numberStyle = (self.descriptor.scientific ? .scientific : .decimal)
                formatter.maximumFractionDigits = self.descriptor.precision
                formatter.minimumFractionDigits = self.descriptor.precision
                formatter.minimumIntegerDigits = 1
                
                str = formatter.string(from: NSNumber(value: last!*self.descriptor.factor as Double))! + " "
            }
        }
        else {
            str = "- "
        }
        
        valueLabel.text = str
        
        setNeedsLayout()
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: size.width, height: valueLabel.sizeThatFits(size).height)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let s1 = label.sizeThatFits(self.bounds.size)
        let s2 = valueLabel.sizeThatFits(self.bounds.size)
        let s3 = unitLabel.sizeThatFits(self.bounds.size)
        
        //We want to align the gap between label and value to the center of the screen. But if the value and unit would exceed the screen, we have to push everything to the left
        let hangOver = (self.bounds.size.width-spacing)/2.0 - s2.width - s3.width - spacing
        let push = hangOver < 0 ? hangOver : 0.0
        
        label.frame = CGRect(x: push, y: (self.bounds.size.height-s1.height)/2.0, width: (self.bounds.size.width-spacing)/2.0, height: s1.height)
        
        valueLabel.frame = CGRect(x: push + (self.bounds.size.width+spacing)/2.0, y: (self.bounds.size.height-s2.height)/2.0, width: s2.width, height: s2.height)
        unitLabel.frame = CGRect(x: valueLabel.frame.maxX, y: (self.bounds.size.height-s3.height)/2.0, width: s3.width, height: s3.height)
        
    }
}
