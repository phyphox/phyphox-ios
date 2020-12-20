//
//  ExperimentEditView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit

private let spacing: CGFloat = 10.0
private let textFieldWidth: CGFloat = 100.0

final class ExperimentEditView: UIView, DynamicViewModule, DescriptorBoundViewModule, UITextFieldDelegate {
    let descriptor: EditViewDescriptor

    private let displayLink = DisplayLink(refreshRate: 5)

    var active = false {
        didSet {
            displayLink.active = active
            if active {
                setNeedsUpdate()
            }
        }
    }

    private var edited = false

    private let textField: UITextField
    private let unitLabel: UILabel?
    private let label = UILabel()

    required init?(descriptor: EditViewDescriptor) {
        self.descriptor = descriptor

        label.numberOfLines = 0
        label.text = descriptor.localizedLabel
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = kTextColor
        label.textAlignment = .right

        textField = UITextField()
        textField.backgroundColor = kLightBackgroundColor
        textField.textColor = kTextColor
        
        textField.returnKeyType = .done
        
        textField.borderStyle = .roundedRect
        
        if descriptor.unit != nil {
            unitLabel = {
                let l = UILabel()
                l.text = descriptor.localizedUnit
                l.textColor = kTextColor
                
                l.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.subheadline)
                
                return l
            }()
        }
        else {
            unitLabel = nil
        }
        
        super.init(frame: .zero)

        registerForUpdatesFromBuffer(descriptor.buffer)
        descriptor.buffer.attachedToTextField = true

        textField.addTarget(self, action: #selector(hideKeyboard(_:)), for: .editingDidEndOnExit)

        textField.delegate = self
        
        textField.addTarget(self, action: #selector(ExperimentEditView.textFieldChanged), for: .editingChanged)

        addSubview(label)
        addSubview(textField)
        
        if let unitLabel = unitLabel {
            addSubview(unitLabel)
        }

        attachDisplayLink(displayLink)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func formattedValue(_ raw: Double) -> String {
        return (descriptor.decimal ? String(raw) : String(Int(raw)))
    }
    
    @objc func hideKeyboard(_: UITextField) {
        textField.endEditing(true)
    }
    
    @objc func textFieldChanged() {
        edited = true
    }
    
    func textFieldDidEndEditing(_: UITextField) {
        if edited {
            edited = false

            let rawValue: Double

            if descriptor.decimal {
                if descriptor.signed {
                    rawValue = Double(textField.text ?? "") ?? 0
                }
                else {
                    rawValue = abs(Double(textField.text ?? "") ?? 0)
                }
            }
            else {
                if descriptor.signed {
                    rawValue = floor(Double(textField.text ?? "") ?? 0)
                }
                else {
                    rawValue = floor(abs(Double(textField.text ?? "") ?? 0))
                }
            }

            var value = rawValue/descriptor.factor

            if descriptor.min.isFinite && value < descriptor.min {
                value = descriptor.min
            }
            if descriptor.max.isFinite && value > descriptor.max {
                value = descriptor.max
            }

            textField.text = formattedValue(rawValue)

            descriptor.buffer.replaceValues([value])
            
            descriptor.buffer.triggerUserInput()
        }
    }

    private var wantsUpdate = false

    func setNeedsUpdate() {
        wantsUpdate = true
    }

    private func update() {
        let value = descriptor.value
        let rawValue = value * descriptor.factor

        textField.text = formattedValue(rawValue)
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
        let w = (bounds.width - spacing)/2.0
        
        label.frame = CGRect(origin: CGPoint(x: 0, y: (bounds.height - h)/2.0), size: CGSize(width: w, height: h))
        
        var actualTextFieldWidth = textFieldWidth
        
        if let unitLabel = unitLabel {
            let s3 = unitLabel.sizeThatFits(self.bounds.size)

            if actualTextFieldWidth + s3.width + spacing > w {
               actualTextFieldWidth = w - s3.width - spacing
            }

            unitLabel.frame = CGRect(origin: CGPoint(x: (bounds.width + spacing)/2.0 + actualTextFieldWidth + spacing, y: (bounds.height - s3.height)/2.0), size: s3)
        }
        
        textField.frame = CGRect(origin: CGPoint(x: (bounds.width + spacing)/2.0, y: (bounds.height - h2)/2.0), size: CGSize(width: actualTextFieldWidth, height: h2))
    }
}

extension ExperimentEditView: DisplayLinkListener {
    func display(_ displayLink: DisplayLink) {
        if wantsUpdate {
            wantsUpdate = false
            update()
        }
    }
}
