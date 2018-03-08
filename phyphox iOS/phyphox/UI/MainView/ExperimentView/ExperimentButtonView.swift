//
//  ExperimentButtonView.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 12.11.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

final class ExperimentButtonView: ExperimentViewModule<ButtonViewDescriptor> {
    let button: UIButton
    let spacing = CGFloat(20.0)

    var buttonTappedCallback: (() -> Void)?

    required init?(descriptor: ButtonViewDescriptor) {
        button = UIButton()
        button.backgroundColor = kLightBackgroundColor
        button.setTitle(descriptor.localizedLabel, for: UIControlState())
      
        super.init(descriptor: descriptor)
        
        button.addTarget(self, action: #selector(ExperimentButtonView.buttonPressed), for: .touchUpInside)
        
        addSubview(button)
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
