//
//  ExperimentEditView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

private let spacing: CGFloat = 10.0
private let textFieldWidth: CGFloat = 100.0

final class ExperimentEditView: ExperimentViewModule<EditViewDescriptor>, UITextFieldDelegate, DataBufferObserver {
    let textField: UITextField
    let unitLabel: UILabel?
    
    var edited = false
    
    func formattedValue(_ raw: Double) -> String {
        return (descriptor.decimal ? String(raw) : String(Int(raw)))
    }
    
    required init(descriptor: EditViewDescriptor) {
        textField = UITextField()
        textField.backgroundColor = kLightBackgroundColor
        textField.textColor = kTextColor
        
        textField.returnKeyType = .done
        
        textField.borderStyle = .roundedRect
        
        if descriptor.unit != nil {
            unitLabel = {
                let l = UILabel()
                l.text = descriptor.unit
                l.textColor = kTextColor
                
                l.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.subheadline)
                
                return l
            }()
        }
        else {
            unitLabel = nil
        }
        
        super.init(descriptor: descriptor)
        
        descriptor.buffer.addObserver(self)
        
        textField.addTarget(self, action: #selector(hideKeyboard(_:)), for: .editingDidEndOnExit)
        
        updateTextField(textField, write: false)
        
        textField.delegate = self
        
        textField.addTarget(self, action: #selector(ExperimentEditView.textFieldChanged), for: .editingChanged)
        
        addSubview(textField)
        if unitLabel != nil {
            addSubview(unitLabel!)
        }
        
        label.textAlignment = NSTextAlignment.right
    }
    
    override func unregisterFromBuffer() {
        descriptor.buffer.removeObserver(self)
    }
    
    @objc func hideKeyboard(_: UITextField) {
        textField.endEditing(true)
    }
    
    @objc func textFieldChanged() {
        edited = true
    }
    
    func textFieldDidEndEditing(_: UITextField) {
        if edited {
            updateTextField(textField, write: true)
            edited = false
        }
    }
    
    func dataBufferUpdated(_ buffer: DataBuffer, noData: Bool) {
        updateTextField(textField, write: false, forceReadFromBuffer: true)
    }
    
    func updateTextField(_: UITextField, write: Bool, forceReadFromBuffer: Bool = false) {
        var val: Double
        
        if forceReadFromBuffer || textField.text?.characters.count == 0 || Double(textField.text!) == nil {
            val = descriptor.value
            
            textField.text = formattedValue(val*self.descriptor.factor)
        }
        else {
            let rawVal: Double
            
            if descriptor.decimal {
                if descriptor.signed {
                    rawVal = Double(textField.text!)!
                }
                else {
                    rawVal = abs(Double(textField.text!)!)
                }
            }
            else {
                if descriptor.signed {
                    rawVal = floor(Double(textField.text!)!)
                }
                else {
                    rawVal = floor(abs(Double(textField.text!)!))
                }
            }
            
            val = rawVal/self.descriptor.factor
            
            if (descriptor.min.isFinite && val < descriptor.min) {
                val = descriptor.min
            }
            
            if (descriptor.max.isFinite && val > descriptor.max) {
                val = descriptor.max
            }
            
            textField.text = formattedValue(rawVal)
        }
        
        if write {
            descriptor.buffer.replaceValues([val])
        }
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        //We want to have the gap between label and value centered, so we require atwice the width of the larger half
        let s1 = label.sizeThatFits(size)
        var s2 = textField.sizeThatFits(size)
        s2.width = textFieldWidth
        
        var height = max(s1.height, s2.height)
        
        let left = s1.width + spacing/2.0
        var right = s2.width + spacing/2.0
        
        if unitLabel != nil {
            let s3 = unitLabel!.sizeThatFits(size)
            right += (spacing+s3.width)
            height = max(height, s3.height)
        }
        
        let width = min(2.0 * max(left, right), size.width)
        
        return CGSize(width: width, height: height)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let h = label.sizeThatFits(self.bounds.size).height
        let h2 = textField.sizeThatFits(self.bounds.size).height
        let w = (self.bounds.size.width-spacing)/2.0
        
        label.frame = CGRect(origin: CGPoint(x: 0, y: (self.bounds.size.height-h)/2.0), size: CGSize(width: w, height: h))
        
        var actualTextFieldWidth = textFieldWidth
        
        if unitLabel != nil {
            let s3 = unitLabel!.sizeThatFits(self.bounds.size)
            if actualTextFieldWidth + s3.width + spacing > w {
               actualTextFieldWidth = w - s3.width - spacing
            }
            unitLabel!.frame = CGRect(origin: CGPoint(x: (self.bounds.size.width+spacing)/2.0+actualTextFieldWidth+spacing, y: (self.bounds.size.height-s3.height)/2.0), size: s3)
        }
        
        textField.frame = CGRect(origin: CGPoint(x: (self.bounds.size.width+spacing)/2.0, y: (self.bounds.size.height-h2)/2.0), size: CGSize(width: actualTextFieldWidth, height: h2))
    }
}
