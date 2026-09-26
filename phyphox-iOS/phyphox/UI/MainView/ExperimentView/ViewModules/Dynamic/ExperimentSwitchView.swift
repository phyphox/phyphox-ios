//
//  ExperimentSwitchView.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 21.10.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

private let spacing: CGFloat = 10.0
private let textFieldWidth: CGFloat = 100.0

final class ExperimentSwitchView: UIView, DynamicViewModule, DescriptorBoundViewModule, AnalysisLimitedViewModule {
    
    let descriptor : SwitchViewDescriptor
    
    var analysisRunning: Bool = false
    
    private let displayLink = DisplayLink(refreshRate: 5)
    
    let switchUI: UISwitch
    let label =  UILabel()
    
    var active = false {
        didSet{
            displayLink.active = active
            if active {
                setNeedsUpdate()
            }
        }
    }
    
    private func update(){
        //Seeded by Experiment.seedInputDefaults() (see the note there); this path only runs for the on-screen view collection

        let value = descriptor.value
        var state = false
        
        if (value != 0 ){
            state = true
        }
        
        switchUI.setOn(state, animated: true)
    }
    
    required init?(descriptor: Descriptor, resourceFolder: URL?) {
        self.descriptor = descriptor
        
        label.numberOfLines = 0
        label.text = descriptor.localizedLabel
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = UIColor(named: "textColor")
        //verticalLayout: the label on its own line, following align (left by default); without a label the switch takes
        //the row (1.21)
        label.textAlignment = descriptor.verticalLayout ? descriptor.align.textAlignment : .right
        label.isHidden = !descriptor.hasLabel
        
        switchUI = UISwitch()
        
        if(descriptor.value == 0){
            switchUI.isOn = false
        } else {
            switchUI.isOn = true
        }
        switchUI.transform = CGAffineTransformMakeScale(0.65, 0.65)
        
        super.init(frame: .zero)
        
        switchUI.addTarget(self, action: #selector(setState(_:)), for: UIControl.Event.valueChanged)
        
        registerForUpdatesFromBuffer(descriptor.buffer)
        
        addSubview(label)
        addSubview(switchUI)
        
        attachDisplayLink(displayLink)
        
    }
    
    @objc func setState(_ sender: UISwitch){
        let state = sender.isOn
        var value: Double = 0
        if(state){
            value = 1
        }
        
        descriptor.buffer.replaceValues([value])
        descriptor.buffer.triggerUserInput()
        
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var wantsUpdate = false
    func setNeedsUpdate() {
        wantsUpdate = true
    }
    
    var dynamicLabelHeight = 0.0
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        if !descriptor.hasLabel || descriptor.verticalLayout {
            dynamicLabelHeight = Utility.measureHeightOfText(descriptor.hasLabel ? (label.text ?? "-") : "-") * 1.5
            let labelHeight = descriptor.hasLabel ? label.sizeThatFits(CGSize(width: size.width, height: CGFLOAT_MAX)).height : 0
            return CGSize(width: size.width, height: labelHeight + dynamicLabelHeight)
        }

        let s1 = label.sizeThatFits(size)
        var s2 = switchUI.sizeThatFits(size)
        s2.width = textFieldWidth
        
        let left = s1.width + spacing/2.0
        let right = s2.width + spacing/2.0
        
        dynamicLabelHeight = Utility.measureHeightOfText(label.text ?? "-") * 1.5
        
        let width = min(2.0 * max(left, right), size.width)
        
        return CGSize(width: width, height: dynamicLabelHeight)
        
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let h2 = switchUI.sizeThatFits(self.bounds.size).height
        let w = (bounds.width - spacing)/2.0

        if !descriptor.hasLabel || descriptor.verticalLayout {
            //Label row above (if any), the switch in its own row where align puts it (the left edge by default)
            let labelHeight = descriptor.hasLabel ? label.sizeThatFits(CGSize(width: bounds.width, height: CGFLOAT_MAX)).height : 0
            label.frame = CGRect(x: 0, y: 0, width: bounds.width, height: labelHeight)
            let rowHeight = bounds.height - labelHeight
            switchUI.frame = CGRect(origin: CGPoint(x: 0, y: labelHeight + (rowHeight - (h2 - 10.0))/2.0), size: CGSize(width: textFieldWidth, height: h2))
            //The switch is scaled down, so its rendered width (the frame after the transform) places it, not the 100 pt
            switch descriptor.align {
            case .left: break
            case .center: switchUI.center.x = bounds.width / 2.0
            case .right: switchUI.center.x = bounds.width - switchUI.frame.width / 2.0
            }
            return
        }
        
        label.frame =  CGRect(origin: CGPoint(x: 0, y: (bounds.height - dynamicLabelHeight)/2.0), size: CGSize(width: w, height: dynamicLabelHeight))
        
        switchUI.frame = CGRect(origin: CGPoint(x: (bounds.width + spacing)/2.0, y: (bounds.height - ( h2 - 10.0))/2.0), size: CGSize(width: textFieldWidth, height: h2))
    }
    
}

extension ExperimentSwitchView: DisplayLinkListener {
    func display(_ displayLink: DisplayLink) {
        if wantsUpdate && !analysisRunning {
            wantsUpdate = false
            update()
        }
    }
}


extension ExperimentSwitchView: VisibilityControllableViewModule {
    var visibilityBuffer: DataBuffer? { descriptor.visibilityBuffer }
}
