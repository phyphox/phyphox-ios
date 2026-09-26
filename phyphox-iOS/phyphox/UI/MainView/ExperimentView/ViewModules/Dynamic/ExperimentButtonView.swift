//
//  ExperimentButtonView.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 12.11.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

private let spacing: CGFloat = 5.0

protocol ButtonViewTriggerCallback {
    func finished()
}

final class ExperimentButtonView: UIView, DescriptorBoundViewModule, ButtonViewTriggerCallback, DynamicViewModule, ResizingViewModule {
    //Asks the experiment screen to re-measure the row: the button is as wide as its label, which a mapping can change
    var onResize: (() -> Void)?
    
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
        
        //A system button (corner shape, press and disabled feedback, Dynamic Type) in the app's own neutral colours,
        //which follow the in-app theme setting where the system tint would not
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = UIColor(named: "lightBackgroundColor")
        configuration.baseForegroundColor = UIColor(named: "textColor")
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20)
        configuration.titleAlignment = .center
        configuration.titleLineBreakMode = .byWordWrapping
        configuration.title = ExperimentButtonView.displayTitle(descriptor.localizedLabel)
        button = UIButton(configuration: configuration)
        
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
    
    ///An empty label still fills one text line, so the button keeps its height (the configuration would drop the line)
    private static func displayTitle(_ title: String) -> String {
        return title.isEmpty ? "\u{00A0}" : title
    }
    
    private func setTitle(_ title: String) {
        let title = ExperimentButtonView.displayTitle(title)
        guard button.configuration?.title != title else { return }
        let unbounded = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let before = button.sizeThatFits(unbounded)
        button.configuration?.title = title
        //The configuration is applied in the button's next layout pass; until then it measures the old title
        button.layoutIfNeeded()
        if button.sizeThatFits(unbounded) != before {
            onResize?()
        }
        setNeedsLayout()
    }
    
    private func update(){
        
        if let last = descriptor.buffer?.last, !last.isNaN {
            var mapped = false
            
            for mapping in descriptor.mappings {
                if mapping.range.contains(last) {
                    setTitle(mapping.replacement)
                    mapped = true
                    break
                }
            }
            
            if !mapped {
                setTitle(descriptor.localizedLabel)
            }
        }
        
        else {
            setTitle(descriptor.localizedLabel)
        }
        
    }

    @objc private func buttonPressed() {
        //Disabled (and drawn so by the configuration) until the trigger has run, as on Android
        button.isEnabled = false
        buttonTappedCallback?()
    }
    
    func finished() {
        DispatchQueue.main.async {
            self.button.isEnabled = true
        }
    }
    
    ///The button's own size, wrapped onto more lines when the label does not fit the width
    private func buttonSize(fitting width: CGFloat) -> CGSize {
        let fitted = button.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        guard width.isFinite, fitted.width > width else { return fitted }
        let wrapped = button.systemLayoutSizeFitting(CGSize(width: width, height: 0), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        return CGSize(width: width, height: Swift.max(wrapped.height, fitted.height))
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let s = buttonSize(fitting: size.width - 2*spacing)
        return CGSize(width: s.width+2*spacing, height: s.height+2*spacing)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let w = Swift.min(buttonSize(fitting: bounds.width - 2*spacing).width, bounds.width - 2*spacing)
        
        button.frame = CGRect(origin: CGPoint(x: (self.bounds.size.width-w)/2.0, y: spacing), size: CGSize(width: w, height: self.bounds.height-2*spacing))
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

extension ExperimentButtonView: VisibilityControllableViewModule {
    var visibilityBuffer: DataBuffer? { descriptor.visibilityBuffer }
}
