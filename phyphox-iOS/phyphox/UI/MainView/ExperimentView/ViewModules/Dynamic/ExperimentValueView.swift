//
//  ExperimentValueView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit

private let spacing: CGFloat = 10.0

final class ExperimentValueView: UIView, DynamicViewModule, DescriptorBoundViewModule {
    let descriptor: ValueViewDescriptor

    private let label = UILabel()
    private let valueLabel = UILabel()
    private let unitLabel = UILabel()

    private let displayLink = DisplayLink(refreshRate: 0)

    var active = false {
        didSet {
            displayLink.active = active
            if active {
                setNeedsUpdate()
            }
        }
    }
    
    required init?(descriptor: ValueViewDescriptor) {
        self.descriptor = descriptor

        super.init(frame: .zero)

        label.numberOfLines = 0
        label.text = descriptor.localizedLabel
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = descriptor.color
        label.textAlignment = .right

        valueLabel.text = "- "
        valueLabel.textColor = descriptor.color
        let defaultFont = UIFont.preferredFont(forTextStyle: .headline)
        valueLabel.font = UIFont.init(descriptor: defaultFont.fontDescriptor, size: CGFloat(descriptor.size) * defaultFont.pointSize)
        valueLabel.textAlignment = .left
        
        unitLabel.text = descriptor.localizedUnit
        unitLabel.textColor = descriptor.color
        unitLabel.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline)
        unitLabel.textAlignment = .left
        
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
                unitLabel.text = descriptor.localizedUnit
                
                let formatter = NumberFormatter()
                formatter.numberStyle = descriptor.scientific ? .scientific : .decimal
                formatter.maximumFractionDigits = descriptor.precision
                formatter.minimumFractionDigits = descriptor.precision
                formatter.minimumIntegerDigits = 1

                let number = NSNumber(value: last * descriptor.factor)
                valueLabel.text = (formatter.string(from: number) ?? "-") + " "
            }
        }
        else {
            valueLabel.text = "- "
        }

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
        let hangOver = (bounds.width - 2*spacing)/2.0 - s2.width - s3.width - spacing
        let push = hangOver < 0 ? hangOver : 0.0
        
        label.frame = CGRect(x: push, y: (bounds.height - s1.height)/2.0, width: bounds.width/2.0 - spacing, height: s1.height)
        
        valueLabel.frame = CGRect(x: label.frame.maxX + spacing, y: (bounds.height - s2.height)/2.0, width: s2.width, height: s2.height)

        unitLabel.frame = CGRect(x: valueLabel.frame.maxX, y: (bounds.height - s3.height)/2.0, width: s3.width, height: s3.height)
    }
}

extension ExperimentValueView: DisplayLinkListener {
    func display(_ displayLink: DisplayLink) {
        if wantsUpdate {
            wantsUpdate = false
            update()
        }
    }
}
