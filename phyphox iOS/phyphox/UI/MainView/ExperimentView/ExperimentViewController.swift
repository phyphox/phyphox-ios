//
//  ExperimentViewController.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 09.10.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

protocol ModuleExclusiveViewDelegate {
    func presentExclusiveView(_ view: UIView)
    func hideExclusiveView()
}

final class ExperimentViewController: UIViewController, ModuleExclusiveViewDelegate {
    private let modules: [UIView]
    var exclusiveView: UIView? = nil
    
    private let scrollView = UIScrollView()
    private let linearView = UIView()
    
    let insetTop: CGFloat = 10
    
    @available(*, unavailable)
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        fatalError("Unavailable")
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Unavailable")
    }
    
    init(modules: [UIView]) {
        self.modules = modules
        super.init(nibName: nil, bundle: nil)
        
        for module in modules {
            if let eMod = module as? GraphViewModule {
                eMod.delegate = self
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardFrameChanged(_:)), name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardFrameChanged(_:)), name:NSNotification.Name.UIKeyboardDidChangeFrame, object: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for module in modules {
            linearView.addSubview(module)
        }
        scrollView.addSubview(linearView)
        scrollView.backgroundColor = kBackgroundColor
        scrollView.contentInset = UIEdgeInsetsMake(insetTop, 0, 0, 0)
        self.view.addSubview(scrollView)
    }
    
    func updateLayout(_ animate: Bool) {
        scrollView.frame = view.bounds
        
        var contentSize = CGRect(x: 0, y: 0, width: view.bounds.width, height: 0)
        var availableSize = view.bounds.size
        availableSize.height = availableSize.height - insetTop
        
        for module in modules {
            let hidden: Bool
            if self.exclusiveView != nil && module != self.exclusiveView {
                hidden = true
            } else {
                hidden = false
                let s = module.sizeThatFits(availableSize)
                let frame = CGRect(x: (view.bounds.width-s.width)/2.0, y: contentSize.height, width: s.width, height: s.height)
                
                if animate {
                    if let eMod = module as? GraphViewModule {
                        eMod.animateFrame(frame)
                    } else {
                        module.frame = frame
                    }
                } else {
                    module.frame = frame
                }
                
                contentSize = CGRect(x: 0, y: 0, width: view.bounds.width, height: contentSize.height + s.height)
            }
            
            if module.isHidden != hidden {
                if animate {
                    UIView.transition(with: module, duration: 0.15,  options: .transitionCrossDissolve, animations: {
                        module.isHidden = hidden
                        }, completion: nil)
                } else {
                    module.isHidden = hidden
                }
            }
        }
        
        linearView.frame = contentSize
        scrollView.contentSize = contentSize.size
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        updateLayout(false)
    }
    
    //MARK: - Keyboard handler
    
    @objc private func keyboardFrameChanged(_ notification: Notification) {
        func UIViewAnimationOptionsFromUIViewAnimationCurve(_ curve: UIViewAnimationCurve) -> UIViewAnimationOptions  {
            let testOptions = UInt(UIViewAnimationCurve.linear.rawValue << 16);
            
            if (testOptions != UIViewAnimationOptions.curveLinear.rawValue) {
                NSLog("Unexpected implementation of UIViewAnimationOptionCurveLinear");
            }
            
            return UIViewAnimationOptions(rawValue: UInt(curve.rawValue << 16));
        }
        
        let duration = (notification.userInfo![UIKeyboardAnimationDurationUserInfoKey]! as AnyObject).doubleValue!
        
        let curve = UIViewAnimationCurve(rawValue: (notification.userInfo![UIKeyboardAnimationCurveUserInfoKey]! as AnyObject).intValue!)!
        
        var bottomInset: CGFloat = 0.0
        
        if !KeyboardTracker.keyboardFrame.isEmpty {
            bottomInset = view.frame.size.height-view.convert(KeyboardTracker.keyboardFrame, from: nil).origin.y
        }
        
        var contentInset = scrollView.contentInset
        var scrollInset = scrollView.scrollIndicatorInsets
        
        contentInset.bottom = bottomInset
        scrollInset.bottom = bottomInset
        
        UIView.animate(withDuration: duration, delay: 0.0, options: [UIViewAnimationOptions.beginFromCurrentState, UIViewAnimationOptionsFromUIViewAnimationCurve(curve)], animations: { () -> Void in
            self.scrollView.contentInset = contentInset
            self.scrollView.scrollIndicatorInsets = scrollInset
            }, completion: nil)
    }
    
    func presentExclusiveView(_ view: UIView) {
        exclusiveView = view
        updateLayout(true)
    }
    
    func hideExclusiveView() {
        exclusiveView = nil
        updateLayout(true)
    }
}
