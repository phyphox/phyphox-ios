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

final class ExperimentButtonView: UIView, DescriptorBoundViewModule, ButtonViewTriggerCallback, DynamicViewModule {
    
    let descriptor: ButtonViewDescriptor
    
    private var wantsUpdate = false
    
    private let displayLink = DisplayLink(refreshRate: 0)
    
    var active = false {
        didSet {
            displayLink.active = active
            if active {
                setNeedsUpdate()
            }
        }
    }

    private let button: UIButton
    var analysisRunning: Bool = false

    var buttonTappedCallback: (() -> Void)?

    required init?(descriptor: ButtonViewDescriptor, resourceFolder: URL?) {
        self.descriptor = descriptor
        
        button = UIButton()
        button.backgroundColor = UIColor(named: "lightBackgroundColor")
        button.setTitleColor(button.backgroundColor?.overlayTextColor() ?? UIColor(named: "textColor"), for: .normal)
        button.setTitleColor(kHighlightColor, for: .highlighted)
        button.setTitle(descriptor.localizedLabel, for: UIControl.State())
        
        super.init(frame: .zero)
        
        button.addTarget(self, action: #selector(ExperimentButtonView.buttonPressed), for: .touchUpInside)
        
        addSubview(button)
        
        guard let buffer = descriptor.buffer else{
            return
        }
        registerForUpdatesFromBuffer(buffer)
        attachDisplayLink(displayLink)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setNeedsUpdate() {
        wantsUpdate = true
    }
    
    private func update(){
        
        if let last = descriptor.buffer?.last, !last.isNaN {
            var mapped = false
            
            for mapping in descriptor.mappings {
                if mapping.range.contains(last) {
                    button.setTitle(mapping.replacement, for: .normal)
                    mapped = true
                    break
                }
            }
            
            if !mapped {
                button.setTitle(descriptor.localizedLabel, for: .normal)
            }
        }
        
        else {
            button.setTitle(descriptor.localizedLabel, for: .normal)
        }
        
        setNeedsLayout()
        
    }

    @objc private func buttonPressed() {
        button.isEnabled = false
        button.backgroundColor = UIColor(named: "lightBackgroundHoverColor")
        UIView.animate(withDuration: 0.5, delay: 0.0, options: .allowUserInteraction) {
            self.button.backgroundColor = UIColor(named: "lightBackgroundColor")
        }
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
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                button.setTitleColor(button.backgroundColor?.overlayTextColor() ?? UIColor(named: "textColor"), for: .normal)
            }
        }
    }
}

extension ExperimentButtonView: DisplayLinkListener {
    func display(_ displayLink: DisplayLink) {
        if wantsUpdate && !analysisRunning {
            wantsUpdate = false
            update()
        }
    }
}
