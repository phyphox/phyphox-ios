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

    required init?(descriptor: SeparatorViewDescriptor) {
        self.descriptor = descriptor
        super.init(frame: .zero)
        backgroundColor = descriptor.color
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: size.width, height: descriptor.height * fontScale)
    }
}
