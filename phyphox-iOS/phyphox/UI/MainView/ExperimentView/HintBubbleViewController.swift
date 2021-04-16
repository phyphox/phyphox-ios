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
    let label: UILabel
    
    init(text: String, maxWidth: Int = 250, onDismiss: @escaping () -> Void) {
        self.callback = onDismiss
        label = UILabel()
        
        super.init(nibName: nil, bundle: nil)
        
        self.modalPresentationStyle = .popover
        
        label.text = text
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        label.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body)
        label.textColor = kDarkBackgroundColor
        let maxSize = CGSize(width: maxWidth, height: 250)
        label.frame.size = label.sizeThatFits(maxSize)
        let paddedFrame = label.frame.insetBy(dx: -10, dy: -10)
        
        self.view.addSubview(label)
        self.preferredContentSize = paddedFrame.size
        
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
    
    override func viewWillAppear(_ animated: Bool) {
        if self.popoverPresentationController!.arrowDirection == .up {
            label.frame = CGRect.init(x: 10, y: self.view.frame.maxY-label.frame.height-10, width: label.frame.width, height: label.frame.height)
        } else if self.popoverPresentationController!.arrowDirection == .left {
            label.frame = CGRect.init(x: self.view.frame.maxX-label.frame.width-10, y: 10, width: label.frame.width, height: label.frame.height)
        } else {
            label.frame = CGRect.init(x: 10, y: 10, width: label.frame.width, height: label.frame.height)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        callback()
    }
    
}
