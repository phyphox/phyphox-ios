//
//  ExperimentDropdownView.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 24.10.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

private let spacing: CGFloat = 10.0
private let minTextFieldWidth: CGFloat = 100.0


final class ExperimentDropdownView: UIView, DynamicViewModule, DescriptorBoundViewModule, AnalysisLimitedViewModule {
    
    var descriptor: DropdownViewDescriptor
    var analysisRunning: Bool = false
    
    // Checks weather the item is selected from app or web dropdown. If not, set the first item as default value
    var setDropdownTitleAsDefaultValue: Bool = true
    
    private let dropdown: UIButton
    private let label =  UILabel()
    
    var dynamicLabelHeight = 0.0
    
    private let displayLink = DisplayLink(refreshRate: 5)
    
    var currentSelectedValue: Double = 0.0
    var isLaunchedFirstTime = true
    
    private var wantsUpdate = false

    var active = false {
        didSet {
            displayLink.active = active
            if active {
                setNeedsUpdate()
            }
        }
    }
   
    required init(descriptor: DropdownViewDescriptor, resourceFolder: URL?) {
        self.descriptor = descriptor
        
        label.numberOfLines = 0
        label.text = descriptor.localizedLabel
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = UIColor(named: "textColor")
        label.textAlignment = .right
        
        dropdown = UIButton(type : .system)
        dropdown.backgroundColor = UIColor.lightGray.withAlphaComponent(0.2)
        dropdown.layer.cornerRadius = 8
        dropdown.contentHorizontalAlignment = .center
                
        super.init(frame: .zero)
        
        dropdown.addTarget(self, action: #selector(showAlertController), for: .touchUpInside)
        
        registerForUpdatesFromBuffer(descriptor.buffer)
        
        addSubview(label)
        addSubview(dropdown)
        
        attachDisplayLink(displayLink)
    }
   
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let s2 = dropdown.sizeThatFits(size)
        
        let maxLabelWidth = (size.width-3*spacing)/2.0
        let labelWidth = s2.width > maxLabelWidth ? 2*maxLabelWidth - s2.width : maxLabelWidth
        
        let s1 = label.sizeThatFits(CGSize(width: labelWidth, height: size.height))
        return CGSize(width: size.width, height: max(s1.height, s2.height))
    }
    
    override func layoutSubviews() {
        let s2 = dropdown.sizeThatFits(self.bounds.size)
        
        let maxLabelWidth = (self.bounds.width-3*spacing)/2.0
        let labelWidth = s2.width > maxLabelWidth ? 2*maxLabelWidth - s2.width : maxLabelWidth

        let s1 = label.sizeThatFits(CGSize(width: labelWidth, height: self.bounds.height))
        
        let totalHeight = max(s1.height, s2.height)
        
        label.frame = CGRect(x: spacing, y: 0, width: labelWidth, height: totalHeight)
        dropdown.frame = CGRect(x: 2*spacing + labelWidth, y: 0, width: max(s2.width, minTextFieldWidth), height: totalHeight)
        
    }
    
   
    @objc private func showAlertController(sender: UIButton) {
        
        let actionSheet = UIAlertController(title: localize("chooseOption"), message: "", preferredStyle: .actionSheet)
        
        for option in descriptor.localizedMappings {
            
            let title: String = if let replacement = option.replacement, replacement != "" {
                replacement
            } else {
                String(option.value)
            }
           
            let action = UIAlertAction(title: title, style: .default) { _ in
                self.setDropdownTitleAsDefaultValue = false
                self.setDropdownLabel(title)
                self.descriptor.buffer.replaceValues([option.value])
                self.descriptor.buffer.triggerUserInput()
               }
               actionSheet.addAction(action)
           }
        
        let cancelAction = UIAlertAction(title: localize("cancel"), style: .cancel, handler: nil)
            actionSheet.addAction(cancelAction)
        
        //To make the view consistent and crash-safe in ipad or in larger screen
        if let presenter = actionSheet.popoverPresentationController {
            presenter.sourceView = dropdown
            presenter.sourceRect = dropdown.bounds
        }
        
        guard let viewController = self.findViewController() else {
            print("No view controller found in the responder chain")
            return
        }
        
        viewController.present(actionSheet, animated: true, completion: nil)

    }
    
    func setDropdownLabel(_ label: String) {
        if label != dropdown.title(for: .normal) {
            dropdown.setTitle(label, for: .normal)
            setNeedsLayout()
        }
    }
    
    func update(){
        
        if(setDropdownTitleAsDefaultValue){
            let firstElement = descriptor.localizedMappings.first
            let defaultTitle = firstElement?.replacement
            let defaultValue = firstElement?.value ?? 0.0
            if(defaultTitle == ""){
                setDropdownLabel(String(defaultValue))
            } else {
                setDropdownLabel(defaultTitle ?? String(defaultValue))
            }
        } else {
            for option in descriptor.localizedMappings {
                if(option.value == descriptor.value){
                    if let replacement = option.replacement, replacement != "" {
                        setDropdownLabel(replacement)
                    } else {
                        setDropdownLabel(String(option.value))
                    }
                    self.descriptor.buffer.replaceValues([descriptor.value])
                    self.descriptor.buffer.triggerUserInput()
                }
            }
        }
        
    }
    
    
    func setNeedsUpdate() {
        wantsUpdate = true
    }
    
    
}

extension ExperimentDropdownView: DisplayLinkListener {
    func display(_ displayLink: DisplayLink) {
        if wantsUpdate && !analysisRunning {
            setDropdownTitleAsDefaultValue = false
            wantsUpdate = false
            
            update()
        }
    }
}


extension UIView {
    // Traverse the responder chain to find the nearest view controller
    func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while responder != nil {
            if let viewController = responder as? UIViewController {
                return viewController
            }
            responder = responder?.next
        }
        return nil
    }
}
