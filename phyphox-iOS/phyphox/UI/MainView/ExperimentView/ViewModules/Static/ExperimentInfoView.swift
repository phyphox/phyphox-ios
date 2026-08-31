//
//  ExperimentInfoView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit

final class ExperimentInfoView: UIView, DescriptorBoundViewModule, DynamicViewModule {
    func attachDisplayLink(_ displayLink: DisplayLink) {
        
    }
    
    var active = false {
        didSet {
            displayLink.active = active
            if active { setNeedsUpdate() }
        }
    }
    
    func setNeedsUpdate() {
        
    }

    
    let descriptor: InfoViewDescriptor

    private let label = UILabel()
    
    private let displayLink = DisplayLink(refreshRate: 0)

    required init?(descriptor: InfoViewDescriptor, resourceFolder: URL?) {
        self.descriptor = descriptor

        super.init(frame: .zero)

        label.numberOfLines = 0
        label.text = descriptor.localizedLabel
        let fontSize = UIFont.systemFontSize * descriptor.fontSize
        label.font = (descriptor.bold ? UIFont.boldSystemFont(ofSize: fontSize) : (descriptor.italic ? UIFont.italicSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)))
        label.textColor = descriptor.color.autoLightColor()
        switch (descriptor.align) {
            case .left: label.textAlignment = .natural
            case .right: label.textAlignment = UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft ? .left : .right
            case .center: label.textAlignment = .center
        }

        addSubview(label)
        attachDisplayLink(displayLink)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var s = size
        s.width = size.width - 20.0
        s.height = label.sizeThatFits(s).height
        return s
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        label.frame = bounds

    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                label.textColor = descriptor.color.autoLightColor()
            }
        }
    }
}

extension ExperimentInfoView: VisibilityControllableViewModule {
    var visibilityBuffer: DataBuffer? { descriptor.visibilityBuffer }
}
