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
    
    init(text: String, onDismiss: @escaping () -> Void) {
        self.callback = onDismiss
        label = UILabel()
        
        super.init(nibName: nil, bundle: nil)
        
        self.modalPresentationStyle = .popover
        
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
        //The following line was needed to fix label alignment when built with XCode 11. My impression was that the little arrow of the bubble then was also part of self.view.
        label.frame = CGRect.init(x: 10, y: self.view.frame.maxY-label.frame.height-10, width: label.frame.width, height: label.frame.height)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        callback()
    }
    
}
