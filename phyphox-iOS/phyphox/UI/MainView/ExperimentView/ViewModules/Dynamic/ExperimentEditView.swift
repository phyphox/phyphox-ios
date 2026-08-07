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

final class ExperimentEditView: UIView, DynamicViewModule, DescriptorBoundViewModule, UITextFieldDelegate, AnalysisLimitedViewModule {
    let descriptor: EditViewDescriptor

    var analysisRunning: Bool = false
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

    //Background colors indicating the edit state, like on Android: yellow while the value has
    //been changed but not yet committed, a green flash fading out when the value is committed.
    //The colors match Android's phyphox_yellow and phyphox_green.
    private static let changedColor = UIColor(red: 0xed/255.0, green: 0xf6/255.0, blue: 0x68/255.0, alpha: 1.0)
    private static let committedColor = UIColor(red: 0x2b/255.0, green: 0xfb/255.0, blue: 0x4c/255.0, alpha: 1.0)
    private var normalBackgroundColor: UIColor? {
        return UIColor(named: "lightBackgroundColor")
    }

    private let textField: UITextField
    private let unitLabel: UILabel?
    private let label = UILabel()
    
    var dynamicLabelHeight = 0.0
    
    let formatter = NumberFormatter()

    required init?(descriptor: EditViewDescriptor, resourceFolder: URL?) {
        self.descriptor = descriptor

        label.numberOfLines = 0
        label.text = descriptor.localizedLabel
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = UIColor(named: "textColor")
        label.textAlignment = .right

        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ""
        
        textField = UITextField()
        textField.backgroundColor = UIColor(named: "lightBackgroundColor")
        textField.textColor = UIColor(named: "textColor")
        
        textField.returnKeyType = .done
        
        textField.borderStyle = .roundedRect
        textField.keyboardType = .decimalPad
        
        if descriptor.unit != nil {
            unitLabel = {
                let l = UILabel()
                l.text = descriptor.localizedUnit
                l.textColor = UIColor(named: "textColor")
                
                l.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.subheadline)
                
                return l
            }()
        }
        else {
            unitLabel = nil
        }
        
        super.init(frame: .zero)
        
        
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.barTintColor = UIColor(named: "mainBackground")
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: localize("ok"), style: .done, target: self, action: #selector(hideKeyboard(_:)))
        doneButton.width = UIScreen.main.bounds.width / 3
        doneButton.tintColor = kHighlightColor
        if descriptor.signed {
            let pmButton = UIBarButtonItem(title: "+/−", style: .done, target: self, action: #selector(changeSign))
            pmButton.tintColor = UIColor(named: "textColor")
            pmButton.width = UIScreen.main.bounds.width / 3
            toolbar.items = [pmButton, space, doneButton]
        } else {
            toolbar.items = [space, doneButton]
        }
        textField.inputAccessoryView = toolbar


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
        let value = descriptor.decimal ? (raw as NSNumber) : (Int(raw) as NSNumber)
        return formatter.string(from: value) ?? "0"
    }
    
    @objc func hideKeyboard(_: UITextField) {
        textField.endEditing(true)
    }
    
    @objc func textFieldChanged() {
        edited = true
        if textField.isFirstResponder {
            //Same mix as Android's yellow overlay at alpha 100/255 over the field's background
            textField.layer.removeAllAnimations()
            textField.backgroundColor = normalBackgroundColor?.interpolating(to: ExperimentEditView.changedColor, byFraction: 100.0/255.0) ?? ExperimentEditView.changedColor
        }
    }

    func textFieldDidBeginEditing(_: UITextField) {
        //Cancel a leftover commit flash; the changed color only appears once the text changes
        textField.layer.removeAllAnimations()
        textField.backgroundColor = normalBackgroundColor
    }
    
    @objc func changeSign() {
        let text = textField.text ?? ""
        if text.hasPrefix("-") {
            textField.text = String(text.suffix(text.count - 1))
        } else {
            textField.text = "-\(text)"
        }
    }
    
    func textFieldDidEndEditing(_: UITextField) {
        if edited {
            edited = false

            let text = textField.text?.replacingOccurrences(of: ",", with: ".")
            let rawValue: Double

            if descriptor.decimal {
                if descriptor.signed {
                    rawValue = Double(text ?? "") ?? 0
                }
                else {
                    rawValue = abs(Double(text ?? "") ?? 0)
                }
            }
            else {
                if descriptor.signed {
                    rawValue = floor(Double(text ?? "") ?? 0)
                }
                else {
                    rawValue = floor(abs(Double(text ?? "") ?? 0))
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

            //Indicate the commit with a green flash fading back to the normal background,
            //matching Android's 500 ms commit animation
            textField.layer.removeAllAnimations()
            textField.backgroundColor = ExperimentEditView.committedColor
            UIView.animate(withDuration: 0.5) {
                self.textField.backgroundColor = self.normalBackgroundColor
            }
        }
        else {
            textField.backgroundColor = normalBackgroundColor
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

        dynamicLabelHeight = Utility.measureHeightOfText(label.text ?? "-") * 2.5
        let width = min(2.0 * max(left, right), size.width)
        
        
        return CGSize(width: width, height: dynamicLabelHeight)
    }

    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let h2 = textField.sizeThatFits(self.bounds.size).height
        let w = (bounds.width - spacing)/2.0
        
        label.frame = CGRect(origin: CGPoint(x: 0, y: (bounds.height - dynamicLabelHeight)/2.0), size: CGSize(width: w, height: dynamicLabelHeight))
        
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
        if wantsUpdate && !analysisRunning {
            wantsUpdate = false
            update()
        }
    }
}

extension ExperimentEditView: VisibilityControllableViewModule {
    var visibilityBuffer: DataBuffer? { descriptor.visibilityBuffer }
}
