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

    //The unit currently shown (session state, docs/file-format/units.md): the experiment's own unless the Unit system
    //setting or the unit dialog switched it
    private(set) var displayUnitId: String?

    //Edit-state backgrounds like Android's phyphox_yellow (changed, uncommitted) and phyphox_green (commit flash)
    private static let changedColor = UIColor(red: 0xed/255.0, green: 0xf6/255.0, blue: 0x68/255.0, alpha: 1.0)
    private static let committedColor = UIColor(red: 0x2b/255.0, green: 0xfb/255.0, blue: 0x4c/255.0, alpha: 1.0)
    private var normalBackgroundColor: UIColor? {
        return UIColor(named: "lightBackgroundColor")
    }

    let textField: UITextField
    let unitLabel: UILabel?
    let label = UILabel()
    
    var dynamicLabelHeight = 0.0
    
    let formatter = NumberFormatter()

    required init?(descriptor: EditViewDescriptor, resourceFolder: URL?) {
        self.descriptor = descriptor

        label.numberOfLines = 0
        label.text = descriptor.localizedLabel
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = UIColor(named: "textColor")
        //verticalLayout: the label on its own line, following align (left by default); without a label the field takes
        //the whole row (1.21)
        label.textAlignment = descriptor.verticalLayout ? descriptor.align.textAlignment : .right
        label.isHidden = !descriptor.hasLabel

        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ""
        
        textField = UITextField()
        textField.backgroundColor = UIColor(named: "lightBackgroundColor")
        textField.textColor = UIColor(named: "textColor")
        
        textField.returnKeyType = .done
        
        textField.borderStyle = .roundedRect
        textField.keyboardType = .decimalPad
        //At full width the field spans the row with its unit and only its text follows align
        if !descriptor.hasLabel || descriptor.verticalLayout {
            textField.textAlignment = descriptor.align.textAlignment
        }
        
        unitLabel = {
            let l = UILabel()
            l.text = descriptor.localizedUnit
            l.textColor = UIColor(named: "textColor")
            l.accessibilityIdentifier = "edit.unit"
            
            l.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.subheadline)
            
            return l
        }()
        
        super.init(frame: .zero)

        //The Unit system setting is applied on every load (units.md, "The unit-system setting")
        displayUnitId = descriptor.unit.id
        if let id = descriptor.unit.id, descriptor.isConvertible {
            displayUnitId = Units.forSetting(id, SettingBundleHelper.getUnitSystem())
            unitLabel?.text = displayUnitSymbol
            //A tap on the unit offers the other units of the quantity
            unitLabel?.isUserInteractionEnabled = true
            unitLabel?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(unitTapped)))
        }
        
        
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

    //What the field shows for a factored buffer value; a converted value is rounded to six significant digits, as the
    //conversion factors would otherwise fill the field with digits
    private func formattedValue(_ raw: Double) -> String {
        if let conversion = conversion {
            let significant = NumberFormatter()
            significant.numberStyle = .decimal
            significant.groupingSeparator = ""
            significant.usesSignificantDigits = true
            significant.maximumSignificantDigits = 6
            return significant.string(from: conversion.toDisplay(raw) as NSNumber) ?? "0"
        }
        let value = descriptor.decimal ? (raw as NSNumber) : (Int(raw) as NSNumber)
        return formatter.string(from: value) ?? "0"
    }

    //Conversion between the factored buffer value and the shown number; nil while the experiment's unit is shown
    private var conversion: UnitConversion? {
        guard descriptor.isConvertible, let from = descriptor.unit.id, let to = displayUnitId, to != from else { return nil }
        return UnitConversion(from: from, to: to)
    }

    var displayUnitSymbol: String {
        return conversion.map { Units.symbol($0.to) } ?? descriptor.localizedUnit
    }

    //The limits as they apply to the shown number: (min, max) in the display unit (buffer units in the file)
    var displayedLimits: (min: Double, max: Double) {
        func shown(_ limit: Double) -> Double {
            guard limit.isFinite else { return limit }
            return conversion?.toDisplay(limit * descriptor.factor) ?? limit * descriptor.factor
        }
        return (shown(descriptor.min), shown(descriptor.max))
    }

    //What the unit dialog does: show the field in another unit of the same quantity; uncommitted text is discarded
    func setDisplayUnit(_ id: String) {
        guard descriptor.isConvertible, Units.sameQuantity(descriptor.unit.id, id) else { return }
        displayUnitId = id
        if textField.isFirstResponder {
            edited = false //the text typed in the old unit is dropped, not committed
            textField.endEditing(true)
        }
        unitLabel?.text = displayUnitSymbol
        update()
        setNeedsLayout()
    }

    @objc private func unitTapped() {
        guard let id = descriptor.unit.id else { return }
        UnitDialog.show(from: hostingViewController, sourceView: unitLabel, experimentUnitId: id, currentUnitId: displayUnitId ?? id) { [weak self] chosen in
            self?.setDisplayUnit(chosen)
        }
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

            //The typed number is converted back to the experiment's unit before the factor (units.md); the limits are in
            //buffer units
            var value = (conversion?.fromDisplay(rawValue) ?? rawValue)/descriptor.factor

            if descriptor.min.isFinite && value < descriptor.min {
                value = descriptor.min
            }
            if descriptor.max.isFinite && value > descriptor.max {
                value = descriptor.max
            }

            textField.text = formattedValue(rawValue)

            descriptor.buffer.replaceValues([value])

            descriptor.buffer.triggerUserInput()

            //Green commit flash fading back, matching Android's 500 ms animation
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

    func update() {
        //Seeded by Experiment.seedInputDefaults(): this display link only turns over for the active view collection
        //(input-defaults-on-hidden-view)

        let value = descriptor.value
        let rawValue = value * descriptor.factor

        textField.text = formattedValue(rawValue)
    }
    
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        if !descriptor.hasLabel || descriptor.verticalLayout {
            dynamicLabelHeight = Utility.measureHeightOfText(descriptor.hasLabel ? (label.text ?? "-") : "-") * 2.5
            let labelHeight = descriptor.hasLabel ? label.sizeThatFits(CGSize(width: size.width, height: CGFLOAT_MAX)).height : 0
            return CGSize(width: size.width, height: labelHeight + dynamicLabelHeight)
        }

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

        if !descriptor.hasLabel || descriptor.verticalLayout {
            //Label row above (if any), then the field over the whole width with the unit at its right
            let labelHeight = descriptor.hasLabel ? label.sizeThatFits(CGSize(width: bounds.width, height: CGFLOAT_MAX)).height : 0
            label.frame = CGRect(x: 0, y: 0, width: bounds.width, height: labelHeight)
            let rowHeight = bounds.height - labelHeight
            var fieldWidth = bounds.width
            if let unitLabel = unitLabel {
                let s3 = unitLabel.sizeThatFits(self.bounds.size)
                fieldWidth = max(bounds.width - s3.width - spacing, 0)
                unitLabel.frame = CGRect(origin: CGPoint(x: fieldWidth + spacing, y: labelHeight + (rowHeight - s3.height)/2.0), size: s3)
            }
            textField.frame = CGRect(x: 0, y: labelHeight + (rowHeight - h2)/2.0, width: fieldWidth, height: h2)
            return
        }
        
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
