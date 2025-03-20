//
//  ExperimentValueView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit

private let spacing: CGFloat = 10.0

final class ExperimentValueView: UIView, DynamicViewModule, DescriptorBoundViewModule, AnalysisLimitedViewModule {
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
                
                print("descriptor.gpsFormat ", descriptor.gpsFormat)
            
                if let format = descriptor.gpsFormat {
                    valueLabel.text = formatGeoCoordinates(coordinate: Double(number), outputFormat: format, formatter: formatter)
                } else {
                    valueLabel.text = (formatter.string(from: number) ?? "-") + " "
                }
                
            }
        }
        else {
            valueLabel.text = "- "
        }

        setNeedsLayout()
    }
    
    private func formatGeoCoordinates(coordinate : Double , outputFormat: GpsFormat, formatter : NumberFormatter) -> String{
        
        let degree = Int(coordinate)
        let decibleMinutes = fabs((coordinate - Double(degree)) * 60)
        
        let integralMinutes = Int(decibleMinutes)
        let decibleSeconds = fabs(decibleMinutes - Double(integralMinutes)) * 60
        
        print("outputFormat ", outputFormat)
        
        switch(outputFormat){
            
        case .FLOAT:
            return (formatter.string(from: NSNumber(value: coordinate)) ?? "-") + " "
        case .DEGREE_MINUTES:
            return String(degree) + "° " + (formatter.string(from: NSNumber(value: decibleMinutes))  ?? "-") + "' "
        case .DEGREE_MINUTES_SECONDS:
            let seconds = (formatter.string(from: NSNumber(value: decibleSeconds)) ?? "-" )
            return (String(degree) + "° " + String(integralMinutes) + "' "  + seconds + "'' ")
        }
        
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let s2 = valueLabel.sizeThatFits(size)
        let s3 = unitLabel.sizeThatFits(size)
        let valueUnitWidth = s2.width + s3.width
        
        let maxLabelWidth = (size.width-3*spacing)/2.0
        let labelWidth = valueUnitWidth > maxLabelWidth ? 2*maxLabelWidth - valueUnitWidth : maxLabelWidth
        
        let s1 = label.sizeThatFits(CGSize(width: labelWidth, height: size.height))
        return CGSize(width: size.width, height: max(s1.height, s2.height, s3.height))
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let s2 = valueLabel.sizeThatFits(self.bounds.size)
        let s3 = unitLabel.sizeThatFits(self.bounds.size)
        let valueUnitWidth = s2.width + s3.width
        let maxLabelWidth = (self.bounds.width-3*spacing)/2.0
        let labelWidth = valueUnitWidth > maxLabelWidth ? 2*maxLabelWidth - valueUnitWidth : maxLabelWidth

        let s1 = label.sizeThatFits(CGSize(width: labelWidth, height: self.bounds.height))
        
        let totalHeight = max(s1.height, s2.height, s3.height)
        
        label.frame = CGRect(x: spacing, y: 0, width: labelWidth, height: totalHeight)
        valueLabel.frame = CGRect(x: 2*spacing + labelWidth, y: 0, width: s2.width, height: totalHeight)
        unitLabel.frame = CGRect(x: 2*spacing + labelWidth + s2.width, y: 0, width: s3.width, height: totalHeight)
       
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
