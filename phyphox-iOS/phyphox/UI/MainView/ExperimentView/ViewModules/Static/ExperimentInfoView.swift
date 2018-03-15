//
//  ExperimentInfoView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit

final class ExperimentInfoView: UIView, DescriptorBoundViewModule {
    let descriptor: InfoViewDescriptor

    private let label = UILabel()

    required init?(descriptor: InfoViewDescriptor) {
        self.descriptor = descriptor
        
        super.init(frame: .zero)

        label.numberOfLines = 0
        label.text = descriptor.localizedLabel
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.textColor = kTextColor
        label.textAlignment = .right

        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var s = size
        s.width = size.width - 20.0
        return label.sizeThatFits(s)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        label.frame = bounds
    }
}
