//
//  ExperimentValueView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit

private let spacing: CGFloat = 10.0

final class ExperimentValueView: UIView, DynamicViewModule, ResizingViewModule, DescriptorBoundViewModule, AnalysisLimitedViewModule {
    var onResize: (() -> Void)?
    
    let descriptor: ValueViewDescriptor

    let label = UILabel()
    let valueLabel = UILabel()
    let unitLabel = UILabel()
    /** represents which label's text is out of its bound  */
    private var labelOutOfBoundDict = [String: Bool]()

    var analysisRunning: Bool = false
    private let displayLink = DisplayLink(refreshRate: 0)

    //The unit currently shown (session state, docs/file-format/units.md): the experiment's own unless the Unit system
    //setting or the unit dialog switched it; only meaningful while the descriptor's unit is convertible
    private(set) var displayUnitId: String?
    

    var active = false {
        didSet {
            displayLink.active = active
            if active {
                setNeedsUpdate()
            }
        }
    }
    
    var dynamicLabelHeight = 0.0
    
    required init?(descriptor: ValueViewDescriptor, resourceFolder: URL?) {
        self.descriptor = descriptor

        super.init(frame: .zero)

        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.text = descriptor.localizedLabel
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = descriptor.color.autoLightColor()
        //verticalLayout: the label on its own line, following align (left by default); without a label the value takes
        //the whole row (1.21)
        label.textAlignment = descriptor.verticalLayout ? descriptor.align.textAlignment : .right
        label.isHidden = !descriptor.hasLabel

        valueLabel.numberOfLines = 0
        valueLabel.lineBreakMode = .byWordWrapping
        valueLabel.text = "- "
        valueLabel.textColor = descriptor.color.autoLightColor()
        let defaultFont = UIFont.preferredFont(forTextStyle: .headline)
        valueLabel.font = UIFont.init(descriptor: defaultFont.fontDescriptor, size: CGFloat(descriptor.size) * defaultFont.pointSize)
        valueLabel.textAlignment = .left
        
        unitLabel.text = descriptor.localizedUnit
        unitLabel.textColor = descriptor.color.autoLightColor()
        unitLabel.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline)
        unitLabel.textAlignment = .left
        unitLabel.accessibilityIdentifier = "value.unit"
        labelOutOfBoundDict[descriptor.label] = false

        addSubview(valueLabel)
        addSubview(unitLabel)
        addSubview(label)

        //The Unit system setting is applied on every load (units.md, "The unit-system setting")
        displayUnitId = descriptor.unit.id
        if let id = descriptor.unit.id, descriptor.isConvertible {
            displayUnitId = Units.forSetting(id, SettingBundleHelper.getUnitSystem())
            unitLabel.text = displayUnitSymbol
            //A tap on the value and its unit offers the other units of the quantity
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(unitTapped(_:))))
        }

        registerForUpdatesFromBuffer(descriptor.buffer)
        attachDisplayLink(displayLink)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var wantsUpdate = false

    func setNeedsUpdate() {
        wantsUpdate = true
    }

    //Conversion of the factored value into the display unit; nil while the experiment's unit is shown
    private var conversion: UnitConversion? {
        guard descriptor.isConvertible, let from = descriptor.unit.id, let to = displayUnitId, to != from else { return nil }
        return UnitConversion(from: from, to: to)
    }

    //The symbol shown next to the value: the display unit's, or the experiment's
    var displayUnitSymbol: String {
        return conversion.map { Units.symbol($0.to) } ?? descriptor.localizedUnit
    }

    //What the unit dialog does: show the value in another unit of the same quantity
    func setDisplayUnit(_ id: String) {
        guard descriptor.isConvertible, Units.sameQuantity(descriptor.unit.id, id) else { return }
        displayUnitId = id
        update()
    }

    @objc private func unitTapped(_ sender: UITapGestureRecognizer) {
        let point = sender.location(in: self)
        guard valueLabel.frame.insetBy(dx: -spacing, dy: -spacing).contains(point) || unitLabel.frame.insetBy(dx: -spacing, dy: -spacing).contains(point) else { return }
        guard let id = descriptor.unit.id else { return }
        UnitDialog.show(from: hostingViewController, sourceView: unitLabel, experimentUnitId: id, currentUnitId: displayUnitId ?? id) { [weak self] chosen in
            self?.setDisplayUnit(chosen)
        }
    }

    //The number as the element shows it for a buffer value: factor, conversion and the precision rule (units.md,
    //"Precision"): fixed point only, scientific stays as authored
    func formatNumber(_ x: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = descriptor.scientific ? .scientific : .decimal
        var precision = descriptor.precision
        var value = x * descriptor.factor
        if let conversion = conversion {
            value = conversion.toDisplay(value)
            if !descriptor.scientific {
                precision = Units.precision(precision, factor: conversion.scale)
            }
        }
        formatter.maximumFractionDigits = precision
        formatter.minimumFractionDigits = precision
        formatter.minimumIntegerDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "-"
    }

    //The text of the element, number and unit, as the user reads it (for the tests)
    var displayedText: String {
        return ((valueLabel.text ?? "") + (unitLabel.text ?? "")).trimmingCharacters(in: .whitespaces)
    }

    func update() {
        if let last = descriptor.buffer.last, !last.isNaN {
            var mapped = false

            for mapping in descriptor.mappings {
                if mapping.range.contains(last) {
                    valueLabel.text = mapping.replacement
                    unitLabel.text = ""
                    mapped = true
                    break
                }
            }
            
            if !mapped {
                if(descriptor.positiveUnit != nil && last >= 0){
                    unitLabel.text = descriptor.localizedPositiveUnit
                    
                } else if(descriptor.negetiveUnit != nil && last < 0){
                    unitLabel.text = descriptor.localizedNegativeUnit
                    
                } else {
                    unitLabel.text = displayUnitSymbol
                }
               
                if let format = descriptor.valueFormat, format != .FLOAT {
                    let formatter = NumberFormatter()
                    formatter.numberStyle = descriptor.scientific ? .scientific : .decimal
                    formatter.maximumFractionDigits = descriptor.precision
                    formatter.minimumFractionDigits = descriptor.precision
                    formatter.minimumIntegerDigits = 1
                    if(format == .ASCII_){
                        valueLabel.text = convertDecimalToAscii(decimals: descriptor.buffer.toArray())
                    } else {
                        valueLabel.text = formatGeoCoordinates(coordinate: last * descriptor.factor, outputFormat: format, formatter: formatter)
                    }
                    
                } else {
                    valueLabel.text = formatNumber(last) + " "
                }
                
            }
        }
        else {
            valueLabel.text = "- "
        }

        if valueLabel.frame.height != calculateFrames(width: frame.width).valueFrame.height {
            onResize?()
        }
        setNeedsLayout()
    }
    
    private func formatGeoCoordinates(coordinate : Double , outputFormat: ValueFormat, formatter : NumberFormatter) -> String{
        
        let degree = Int(coordinate)
        let decibleMinutes = fabs((coordinate - Double(degree)) * 60)
        
        let integralMinutes = Int(decibleMinutes)
        let decibleSeconds = fabs(decibleMinutes - Double(integralMinutes)) * 60
      
        switch(outputFormat){
            
        case .FLOAT:
            return (formatter.string(from: NSNumber(value: coordinate)) ?? "-") + " "
        case .DEGREE_MINUTES:
            return String(degree) + "° " + (formatter.string(from: NSNumber(value: decibleMinutes))  ?? "-") + "' "
        case .DEGREE_MINUTES_SECONDS:
            let seconds = (formatter.string(from: NSNumber(value: decibleSeconds)) ?? "-" )
            return (String(degree) + "° " + String(integralMinutes) + "' "  + seconds + "'' ")
        case .ASCII_:
            return ""
        }
        
    }
    
    private func convertDecimalToAscii(decimals : [Double?]) -> String{
        var asciiString = ""
        for decimal in decimals {
            if let decimal_ = decimal {
                let intDecimal = Int(round(decimal_))
                if(intDecimal > 31 && intDecimal < 126){
                    if let asciiCharacter = UnicodeScalar(intDecimal) {
                        asciiString +=  Character(asciiCharacter).description
                    } else {
                        print("No valid ASCII character for decimal \(intDecimal).")
                    }
                }
            } else{
                continue
            }
            
        }
        return asciiString
    }
    
    func calculateFrames(width: CGFloat) -> (labelFrame: CGRect, valueFrame: CGRect, unitFrame: CGRect, height: CGFloat) {
        let unrestrictedBounds = CGSize(width: width, height: CGFLOAT_MAX)
        let labelIdeal = label.sizeThatFits(unrestrictedBounds).width
        let valueIdeal = valueLabel.sizeThatFits(unrestrictedBounds).width
        let unitWidth = unitLabel.sizeThatFits(unrestrictedBounds).width
        let valueUnitIdeal = valueIdeal + unitWidth

        if !descriptor.hasLabel || descriptor.verticalLayout {
            //The value and its unit take the whole row; with verticalLayout the label sits on its own line above it
            let rowWidth = max(width - 2*spacing, 0)
            let labelHeight = descriptor.hasLabel ? label.sizeThatFits(CGSize(width: rowWidth, height: CGFLOAT_MAX)).height : 0
            let valueWidth = min(valueIdeal, max(rowWidth - unitWidth, 0))
            let valueHeight = valueLabel.sizeThatFits(CGSize(width: valueWidth, height: CGFLOAT_MAX)).height
            let unitHeight = unitLabel.sizeThatFits(CGSize(width: unitWidth, height: CGFLOAT_MAX)).height
            let rowHeight = max(valueHeight, unitHeight)
            //The value with its unit is not stretched, so align positions it in the row
            let offset: CGFloat
            switch descriptor.align {
            case .left: offset = 0
            case .center: offset = max(rowWidth - valueWidth - unitWidth, 0) / 2.0
            case .right: offset = max(rowWidth - valueWidth - unitWidth, 0)
            }
            let labelFrame = CGRect(x: spacing, y: 0, width: rowWidth, height: labelHeight)
            let valueFrame = CGRect(x: spacing + offset, y: labelHeight, width: valueWidth, height: rowHeight)
            let unitFrame = CGRect(x: spacing + offset + valueWidth, y: labelHeight, width: unitWidth, height: rowHeight)
            return (labelFrame, valueFrame, unitFrame, labelHeight + rowHeight)
        }
        
        let defaultWidth = (width - 3*spacing)/2.0
        var labelWidth = defaultWidth
        var valueUnitWidth = defaultWidth
        
        //Allow value+unit to take up additional space if label has room
        if valueUnitIdeal > defaultWidth && labelIdeal < defaultWidth {
            let availableWidth = 2*defaultWidth - labelIdeal
            valueUnitWidth = min(availableWidth, valueUnitIdeal)
            labelWidth = 2*defaultWidth - valueUnitWidth
        }
        
        let valueWidth = min(valueIdeal, valueUnitWidth - unitWidth)
        
        let labelHeight = label.sizeThatFits(CGSize(width: labelWidth, height: CGFLOAT_MAX)).height
        let valueHeight = valueLabel.sizeThatFits(CGSize(width: valueWidth, height: CGFLOAT_MAX)).height
        let unitHeight = unitLabel.sizeThatFits(CGSize(width: unitWidth, height: CGFLOAT_MAX)).height

        let height = max(labelHeight, valueHeight, unitHeight)
        
        let labelFrame = CGRect(x: spacing, y: 0, width: labelWidth, height: height)
        let valueFrame = CGRect(x: 2*spacing + labelWidth, y: 0, width: valueWidth, height: height)
        let unitFrame = CGRect(x: 2*spacing + labelWidth + valueWidth, y: 0, width: unitWidth, height: height)
        
        return (labelFrame, valueFrame, unitFrame, height)
        
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: size.width, height: calculateFrames(width: size.width).height)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let frames = calculateFrames(width: self.bounds.size.width)
        (label.frame, valueLabel.frame, unitLabel.frame) = (frames.labelFrame, frames.valueFrame, frames.unitFrame)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            label.textColor = descriptor.color.autoLightColor()
            valueLabel.textColor = descriptor.color.autoLightColor()
            unitLabel.textColor = descriptor.color.autoLightColor()
        }
    }
}

extension ExperimentValueView: DisplayLinkListener {
    func display(_ displayLink: DisplayLink) {
        if wantsUpdate && !analysisRunning {
            wantsUpdate = false
            update()
        }
    }
}

extension ExperimentValueView: VisibilityControllableViewModule {
    var visibilityBuffer: DataBuffer? { descriptor.visibilityBuffer }
}
