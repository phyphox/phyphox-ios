//
//  ExperimentViewController.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 09.10.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

protocol ModuleExclusiveViewDelegate {
    func presentExclusiveView(view: UIView)
    func hideExclusiveView()
}

final class ExperimentViewController: UIViewController, ModuleExclusiveViewDelegate {
    private let modules: [UIView]
    var exclusiveView: UIView? = nil
    
    private let scrollView = UIScrollView()
    private let linearView = UIView()
    
    let insetTop: CGFloat = 10
    
    @available(*, unavailable)
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
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
            if let eMod = module as? ExperimentGraphView {
                eMod.delegate = self
            }
        }
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardFrameChanged(_:)), name: UIKeyboardWillChangeFrameNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardFrameChanged(_:)), name:UIKeyboardDidChangeFrameNotification, object: nil)
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
    
    func updateLayout(animate: Bool) {
        scrollView.frame = view.bounds
        
        var contentSize = CGRectMake(0, 0, view.bounds.width, 0)
        var availableSize = view.bounds.size
        availableSize.height = availableSize.height - insetTop
        
        for module in modules {
            let hidden: Bool
            if self.exclusiveView != nil && module != self.exclusiveView {
                hidden = true
            } else {
                hidden = false
                let s = module.sizeThatFits(availableSize)
                let frame = CGRectMake((view.bounds.width-s.width)/2.0, contentSize.height, s.width, s.height)
                
                if animate {
                    if let eMod = module as? ExperimentGraphView {
                        eMod.animateFrame(frame)
                    } else {
                        module.frame = frame
                    }
                } else {
                    module.frame = frame
                }
                
                contentSize = CGRectMake(0, 0, view.bounds.width, contentSize.height + s.height)
            }
            
            if module.hidden != hidden {
                if animate {
                    UIView.transitionWithView(module, duration: 0.15,  options: .TransitionCrossDissolve, animations: {
                        module.hidden = hidden
                        }, completion: nil)
                } else {
                    module.hidden = hidden
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
    
    dynamic private func keyboardFrameChanged(notification: NSNotification) {
        func UIViewAnimationOptionsFromUIViewAnimationCurve(curve: UIViewAnimationCurve) -> UIViewAnimationOptions  {
            let testOptions = UInt(UIViewAnimationCurve.Linear.rawValue << 16);
            
            if (testOptions != UIViewAnimationOptions.CurveLinear.rawValue) {
                NSLog("Unexpected implementation of UIViewAnimationOptionCurveLinear");
            }
            
            return UIViewAnimationOptions(rawValue: UInt(curve.rawValue << 16));
        }
        
        let duration = notification.userInfo![UIKeyboardAnimationDurationUserInfoKey]!.doubleValue!
        
        let curve = UIViewAnimationCurve(rawValue: notification.userInfo![UIKeyboardAnimationCurveUserInfoKey]!.integerValue!)!
        
        var bottomInset: CGFloat = 0.0
        
        if !CGRectIsEmpty(keyboardFrame) {
            bottomInset = view.frame.size.height-view.convertRect(keyboardFrame, fromView: nil).origin.y
        }
        
        var contentInset = scrollView.contentInset
        var scrollInset = scrollView.scrollIndicatorInsets
        
        contentInset.bottom = bottomInset
        scrollInset.bottom = bottomInset
        
        UIView.animateWithDuration(duration, delay: 0.0, options: [UIViewAnimationOptions.BeginFromCurrentState, UIViewAnimationOptionsFromUIViewAnimationCurve(curve)], animations: { () -> Void in
            self.scrollView.contentInset = contentInset
            self.scrollView.scrollIndicatorInsets = scrollInset
            }, completion: nil)
    }
    
    override class func initialize() {
        super.initialize()
        
        NSNotificationCenter.defaultCenter().addObserver(self.self, selector: #selector(keyboardFrameWillChange(_:)), name: UIKeyboardWillChangeFrameNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self.self, selector: #selector(keyboardFrameDidChange(_:)), name:UIKeyboardDidChangeFrameNotification, object: nil)
    }
    
    dynamic private class func keyboardFrameWillChange(notification: NSNotification) {
        keyboardFrame = notification.userInfo![UIKeyboardFrameEndUserInfoKey]!.CGRectValue;
        if (CGRectIsEmpty(keyboardFrame)) {
            keyboardFrame = notification.userInfo![UIKeyboardFrameBeginUserInfoKey]!.CGRectValue;
        }
    }
    
    dynamic private class func keyboardFrameDidChange(notification: NSNotification) {
        keyboardFrame = notification.userInfo![UIKeyboardFrameEndUserInfoKey]!.CGRectValue;
    }
    
    func presentExclusiveView(view: UIView) {
        exclusiveView = view
        updateLayout(true)
    }
    
    func hideExclusiveView() {
        exclusiveView = nil
        updateLayout(true)
    }

    
}
