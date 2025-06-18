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

    private let label = UILabel()
    private let valueLabel = UILabel()
    private let unitLabel = UILabel()
    /** represents which label's text is out of its bound  */
    private var labelOutOfBoundDict = [String: Bool]()

    var analysisRunning: Bool = false
    private let displayLink = DisplayLink(refreshRate: 0)
    

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
        label.textAlignment = .right

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
        labelOutOfBoundDict[descriptor.label] = false

        addSubview(valueLabel)
        addSubview(unitLabel)
        addSubview(label)

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

    private func update() {
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
                    unitLabel.text = descriptor.localizedUnit
                }
               
                let formatter = NumberFormatter()
                formatter.numberStyle = descriptor.scientific ? .scientific : .decimal
                formatter.maximumFractionDigits = descriptor.precision
                formatter.minimumFractionDigits = descriptor.precision
                formatter.minimumIntegerDigits = 1

                let number = NSNumber(value: last * descriptor.factor)
            
                if let format = descriptor.valueFormat {
                    if(format == .ASCII_){
                        valueLabel.text = convertDecimalToAscii(decimals: descriptor.buffer.toArray())
                    } else {
                        valueLabel.text = formatGeoCoordinates(coordinate: Double(number), outputFormat: format, formatter: formatter)
                    }
                    
                } else {
                    valueLabel.text = (formatter.string(from: number) ?? "-") + " "
                }
                
            }
        }
        else {
            valueLabel.text = "- "
        }

        onResize?()
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
    
    func calculateFrames(width: CGFloat) -> (labelFrame: CGRect, valueFrame: CGRect, unitFrame: CGRect) {
        let unrestrictedBounds = CGSize(width: width, height: CGFLOAT_MAX)
        let labelIdeal = label.sizeThatFits(unrestrictedBounds).width
        let valueIdeal = valueLabel.sizeThatFits(unrestrictedBounds).width
        let unitWidth = unitLabel.sizeThatFits(unrestrictedBounds).width
        let valueUnitIdeal = valueIdeal + unitWidth
        
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
        
        return (labelFrame, valueFrame, unitFrame)
        
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: size.width, height: calculateFrames(width: size.width).valueFrame.height)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        (label.frame, valueLabel.frame, unitLabel.frame) = calculateFrames(width: self.bounds.size.width)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                label.textColor = descriptor.color.autoLightColor()
                valueLabel.textColor = descriptor.color.autoLightColor()
                unitLabel.textColor = descriptor.color.autoLightColor()
            }
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
