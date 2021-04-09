//
//  ExperimentButtonView.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 12.11.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

private let spacing: CGFloat = 5.0
private let padding: CGFloat = 20.0

protocol ButtonViewTriggerCallback {
    func finished()
}

final class ExperimentButtonView: UIView, DescriptorBoundViewModule, ButtonViewTriggerCallback {
    let descriptor: ButtonViewDescriptor

    private let button: UIButton

    var buttonTappedCallback: (() -> Void)?

    required init?(descriptor: ButtonViewDescriptor) {
        self.descriptor = descriptor
        
        button = UIButton()
        button.backgroundColor = kLightBackgroundColor
        button.setTitle(descriptor.localizedLabel, for: UIControl.State())
      
        super.init(frame: .zero)
        
        button.addTarget(self, action: #selector(ExperimentButtonView.buttonPressed), for: .touchUpInside)
        
        addSubview(button)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func buttonPressed() {
        button.isEnabled = false
        button.alpha = 0.5
        buttonTappedCallback?()
    }
    
    func finished() {
        DispatchQueue.main.async {
            self.button.alpha = 1
            self.button.isEnabled = true
        }
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let s = button.sizeThatFits(size)
        return CGSize(width: s.width+2*spacing, height: s.height+2*spacing)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let w = button.sizeThatFits(self.bounds.size).width + 2*padding
        
        button.frame = CGRect(origin: CGPoint(x: (self.bounds.size.width-w)/2.0, y: spacing), size: CGSize(width: w, height: self.bounds.height-2*spacing))
    }
}
