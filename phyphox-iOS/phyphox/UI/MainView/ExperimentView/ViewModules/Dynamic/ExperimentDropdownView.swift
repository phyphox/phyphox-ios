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
    
    var isDropDownItemSelected: Bool = false
    
    private let displayLink = DisplayLink(refreshRate: 5)

    var active = false {
        didSet {
            displayLink.active = active
            if active {
                setNeedsUpdate()
            }
        }
    }
    
    private let dropdown: UIButton
    private let label =  UILabel()
    
    var dynamicLabelHeight = 0.0
   
    required init(descriptor: DropdownViewDescriptor, resourceFolder: URL?) {
        self.descriptor = descriptor
        
        label.numberOfLines = 0
        label.text = descriptor.localizedLabel
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = UIColor(named: "textColor")
        label.textAlignment = .right
        
        dropdown = UIButton(type : .system)
        
        dropdown.backgroundColor = UIColor.lightGray.withAlphaComponent(0.2) // Light gray background
        dropdown.layer.cornerRadius = 8
        dropdown.layer.borderColor = UIColor.lightGray.cgColor
        
        dropdown.contentHorizontalAlignment = .center
        dropdown.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10) // Less padding for narrower look
        
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
  
    
    @objc private func showAlertController(sender: UIButton) {
        
        let actionSheet = UIAlertController(title: "Choose an Option", message: "", preferredStyle: .actionSheet)
        
        for option in descriptor.dropDownList.components(separatedBy: ",") {
               let action = UIAlertAction(title: option, style: .default) { _ in
                   self.isDropDownItemSelected = true
                   let value: Double = Double(option) ?? 0.0
                   self.dropdown.setTitle(option, for: .normal)
                   self.descriptor.buffer.replaceValues([value])
                   
                   self.descriptor.buffer.triggerUserInput()
               }
               actionSheet.addAction(action)
           }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            actionSheet.addAction(cancelAction)
        
        guard let viewController = self.findViewController() else {
            print("No view controller found in the responder chain")
            return
        }
        
        viewController.present(actionSheet, animated: true, completion: nil)
        

    }

    private var wantsUpdate = false
    
    func setNeedsUpdate() {
        wantsUpdate = true
    }
    
    func update(){
        
        if(isDropDownItemSelected){
            self.dropdown.setTitle(String(descriptor.value), for: .normal)
            return
        }
        
        //Determine the default title
        let dropDownTitle: String
        if let dropdownDefaultValue = descriptor.defaultValue, descriptor.dropDownList.contains(String(dropdownDefaultValue)) {
            dropDownTitle = String(dropdownDefaultValue)
        } else {
            dropDownTitle = localize("select")
        }
        
        self.dropdown.setTitle(dropDownTitle, for: .normal)
        
        
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
        
        dropdown.frame = CGRect(origin: CGPoint(x: (bounds.width + spacing)/2.0, y: (bounds.height - h2)/2.0), size: CGSize(width: textFieldWidth, height: h2))
        
    }
}

extension ExperimentDropdownView: DisplayLinkListener {
    func display(_ displayLink: DisplayLink) {
        if wantsUpdate && !analysisRunning {
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
