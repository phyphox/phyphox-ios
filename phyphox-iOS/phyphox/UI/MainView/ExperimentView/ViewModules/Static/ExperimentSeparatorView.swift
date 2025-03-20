//
//  ExperimentSeparatorView.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 09.02.17.
//  Copyright © 2017 RWTH Aachen. All rights reserved.
//

import Foundation

import UIKit

final class ExperimentSeparatorView: UIView, DescriptorBoundViewModule {
    let descriptor: SeparatorViewDescriptor
    let fontScale = UIFont.preferredFont(forTextStyle: .footnote).pointSize

    required init?(descriptor: SeparatorViewDescriptor, resourceFolder: URL?) {
        self.descriptor = descriptor
        super.init(frame: .zero)
        backgroundColor = descriptor.color.autoLightColor()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: size.width, height: descriptor.height * fontScale)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                backgroundColor = descriptor.color.autoLightColor()
            }
        }
    }
}
