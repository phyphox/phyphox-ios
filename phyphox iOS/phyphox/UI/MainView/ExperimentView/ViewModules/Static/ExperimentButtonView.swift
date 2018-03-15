//
//  ExperimentButtonView.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 12.11.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

private let spacing: CGFloat = 20.0

final class ExperimentButtonView: UIView, DescriptorBoundViewModule {
    let descriptor: ButtonViewDescriptor

    private let button: UIButton

    var buttonTappedCallback: (() -> Void)?

    required init?(descriptor: ButtonViewDescriptor) {
        self.descriptor = descriptor
        
        button = UIButton()
        button.backgroundColor = kLightBackgroundColor
        button.setTitle(descriptor.localizedLabel, for: UIControlState())
      
        super.init(frame: .zero)
        
        button.addTarget(self, action: #selector(ExperimentButtonView.buttonPressed), for: .touchUpInside)
        
        addSubview(button)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func buttonPressed() {
        buttonTappedCallback?()
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let s = button.sizeThatFits(size)
        return CGSize(width: s.width+2*spacing, height: s.height+2*spacing)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let w = button.sizeThatFits(self.bounds.size).width + 2*spacing
        
        button.frame = CGRect(origin: CGPoint(x: (self.bounds.size.width-w)/2.0, y: spacing), size: CGSize(width: w, height: self.bounds.height-2*spacing))
    }
}
