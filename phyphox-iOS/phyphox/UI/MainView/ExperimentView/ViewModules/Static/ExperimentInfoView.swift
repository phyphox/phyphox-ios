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
        let fontSize = UIFont.systemFontSize * descriptor.fontSize
        label.font = (descriptor.bold ? UIFont.boldSystemFont(ofSize: fontSize) : (descriptor.italic ? UIFont.italicSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)))
        label.textColor = descriptor.color
        switch (descriptor.align) {
            case .left: label.textAlignment = .natural
        case .right: label.textAlignment = UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft ? .left : .right
            case .center: label.textAlignment = .center
        }

        addSubview(label)
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
}
