//
//  HintBubbleViewController.swift
//  phyphox
//
//  Created by Sebastian Staacks on 29.05.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation

class HintBubbleViewController: UIViewController, UIPopoverPresentationControllerDelegate, UIGestureRecognizerDelegate {
    let callback: () -> Void
    
    init(text: String, onDismiss: @escaping () -> Void, button: UIBarButtonItem, source: UIView, delegate: UIPopoverPresentationControllerDelegate) {
        self.callback = onDismiss
        
        super.init(nibName: nil, bundle: nil)
        
        let label = UILabel()
        label.text = text
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        label.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
        label.textColor = kDarkBackgroundColor
        let maxSize = CGSize(width: 250, height: 250)
        label.frame.size = label.sizeThatFits(maxSize)
        label.frame = label.frame.offsetBy(dx: 10, dy: 10)
        let paddedFrame = label.frame.insetBy(dx: -10, dy: -10)
        
        self.view.addSubview(label)
        self.preferredContentSize = paddedFrame.size
        self.modalPresentationStyle = .popover
        guard let pc = self.popoverPresentationController else {
            print("Bubble error: Could not get popoverPresentationController")
            return
        }
        
        pc.permittedArrowDirections = .any
        pc.barButtonItem = button
        pc.sourceView = source
        pc.delegate = delegate
        
        let tapHandler = UITapGestureRecognizer.init(target: self, action: #selector(closeHint))
        tapHandler.delegate = self
        tapHandler.numberOfTapsRequired = 1
        self.view.isUserInteractionEnabled = true
        self.view.addGestureRecognizer(tapHandler)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func closeHint(_ sender: UITapGestureRecognizer? = nil) {
        self.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        callback()
    }
}
