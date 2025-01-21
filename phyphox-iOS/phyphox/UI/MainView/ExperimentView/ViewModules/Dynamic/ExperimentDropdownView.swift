//
//  ExperimentDropdownView.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 24.10.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

private let spacing: CGFloat = 10.0
private let textFieldWidth: CGFloat = 100.0


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
        dropdown.contentHorizontalAlignment = .left
        dropdown.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        
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
        
        let s1 = label.sizeThatFits(size)
        var s2 = dropdown.sizeThatFits(size)
        s2.width = textFieldWidth
        
        let left = s1.width + spacing/2.0
        let right = s2.width + spacing/2.0
        
        dynamicLabelHeight = Utility.measureHeightOfText(label.text ?? "-") * 2.5
        let width = min(2.0 * max(left, right), size.width)
        
        return CGSize(width: width, height: dynamicLabelHeight)
    }
    
    override func layoutSubviews() {
        
        let h2 = dropdown.sizeThatFits(self.bounds.size).height
        let w = (bounds.width - spacing)/2.0
        
        label.frame = CGRect(origin: CGPoint(x: 0, y: (bounds.height - dynamicLabelHeight)/2.0), size: CGSize(width: w, height: dynamicLabelHeight))
        
        dropdown.frame = CGRect(origin: CGPoint(x: (bounds.width + spacing)/2.0, y: (bounds.height - h2)/2.0), size: CGSize(width: textFieldWidth + 20.0, height: h2))
        
    }
    
   
    @objc private func showAlertController(sender: UIButton) {
        
        let actionSheet = UIAlertController(title: "Choose an Option", message: "", preferredStyle: .actionSheet)
        
        for option in descriptor.mappings {
            
            let title: String = option.replacement == "" ? option.value : (option.replacement ?? option.value)
           
            let action = UIAlertAction(title: title, style: .default) { _ in
                self.setDropdownTitleAsDefaultValue = false
                let value: Double = Double(option.value) ?? 0.0
                self.dropdown.setTitle(title, for: .normal)
                self.descriptor.buffer.replaceValues([value])
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
    
    func update(){
        
        if(setDropdownTitleAsDefaultValue){
            let defaultTitle = descriptor.mappings.first?.replacement
            let defaultValue = descriptor.mappings.first?.value
            if(defaultTitle == ""){
                self.dropdown.setTitle(defaultValue, for: .normal)
            } else {
                self.dropdown.setTitle(defaultTitle ?? defaultValue, for: .normal)
            }
            
        } else {
            for option in descriptor.mappings {
                if(String(Double(option.value) ?? 0.0) == String(descriptor.value)){
                    let title: String = option.replacement == "" ? option.value : (option.replacement ?? option.value)
                    self.dropdown.setTitle(title, for: .normal)
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
