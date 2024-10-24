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
    
    private let switchUI: UISwitch
    private let label =  UILabel()
    
    var active = false {
        didSet{
            displayLink.active = active
            if active {
                setNeedsUpdate()
            }
        }
    }
    
    private func update(){
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
        label.textAlignment = .right
        
        switchUI = UISwitch()
        if(descriptor.defaultValue == 0){
            switchUI.isOn = false
        } else {
            switchUI.isOn = true
        }
        
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
        let s1 = label.sizeThatFits(size)
        var s2 = switchUI.sizeThatFits(size)
        s2.width = textFieldWidth
        
        let left = s1.width + spacing/2.0
        let right = s2.width + spacing/2.0
        
        dynamicLabelHeight = Utility.measureHeightofUILabelOnString(line: label.text ?? "-") * 2.5
        
        let width = min(2.0 * max(left, right), size.width)
        
        return CGSize(width: width, height: dynamicLabelHeight)
        
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let h2 = switchUI.sizeThatFits(self.bounds.size).height
        let w = (bounds.width - spacing)/2.0
        
        label.frame =  CGRect(origin: CGPoint(x: 0, y: (bounds.height - dynamicLabelHeight)/2.0), size: CGSize(width: w, height: dynamicLabelHeight))
        
        switchUI.frame = CGRect(origin: CGPoint(x: (bounds.width + spacing)/2.0, y: (bounds.height - h2)/2.0), size: CGSize(width: textFieldWidth, height: h2))
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
