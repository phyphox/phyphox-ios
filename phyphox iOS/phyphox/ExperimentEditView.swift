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

final class ExperimentEditView: ExperimentViewModule<EditViewDescriptor>, UITextFieldDelegate, DataBufferObserver {
    let textField: UITextField
    let unitLabel: UILabel?
    
    var edited = false
    
    func formattedValue(raw: Double) -> String {
        return (descriptor.decimal ? String(Int(raw)) : String(raw))
    }
    
    required init(descriptor: EditViewDescriptor) {
        textField = UITextField()
        textField.returnKeyType = .Done
        
        textField.borderStyle = .RoundedRect
        
        if descriptor.unit != nil {
            unitLabel = {
                let l = UILabel()
                l.text = descriptor.unit
                
                l.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
                
                return l
            }()
        }
        else {
            unitLabel = nil
        }
        
        super.init(descriptor: descriptor)
        
        descriptor.buffer.addObserver(self)
        
        textField.addTarget(self, action: #selector(hideKeyboard(_:)), forControlEvents: .EditingDidEndOnExit)
        
        updateTextField(textField, write: false)
        
        textField.delegate = self
        
        textField.addTarget(self, action: #selector(ExperimentEditView.textFieldChanged), forControlEvents: .EditingChanged)
        
        addSubview(textField)
        if unitLabel != nil {
            addSubview(unitLabel!)
        }
    }
    
    func hideKeyboard(_: UITextField) {
        textField.endEditing(true)
    }
    
    func textFieldChanged() {
        edited = true
    }
    
    func textFieldDidEndEditing(_: UITextField) {
        if edited {
            updateTextField(textField, write: true)
            edited = false
        }
    }
    
    func dataBufferUpdated(buffer: DataBuffer) {
        updateTextField(textField, write: false, forceReadFromBuffer: true)
    }
    
    func updateTextField(_: UITextField, write: Bool, forceReadFromBuffer: Bool = false) {
        let val: Double
        
        if forceReadFromBuffer || textField.text?.characters.count == 0 || Double(textField.text!) == nil {
            val = descriptor.value
            
            textField.text = formattedValue(val*self.descriptor.factor)
        }
        else {
            let rawVal: Double
            
            if descriptor.decimal {
                if descriptor.signed {
                    rawVal = floor(Double(textField.text!)!)
                }
                else {
                    rawVal = floor(abs(Double(textField.text!)!))
                }
            }
            else {
                if descriptor.signed {
                    rawVal = Double(textField.text!)!
                }
                else {
                    rawVal = abs(Double(textField.text!)!)
                }
            }
            
            val = rawVal/self.descriptor.factor
            
            textField.text = formattedValue(rawVal)
        }
        
        if write {
            descriptor.buffer.replaceValues([val])
        }
    }
    
    override func sizeThatFits(size: CGSize) -> CGSize {
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
    
    override func layoutSubviews() {
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
