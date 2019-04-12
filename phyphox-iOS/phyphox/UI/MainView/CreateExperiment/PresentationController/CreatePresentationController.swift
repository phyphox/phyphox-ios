//
//  OverlayPresentationController.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.04.16.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import UIKit

final class OverlayPresentationController: UIPresentationController {
    let dimmingView = UIView()
    
    override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)

        dimmingView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
    }
    
    override func presentationTransitionWillBegin() {
        super.dismissalTransitionWillBegin()
        
        dimmingView.frame = containerView!.bounds
        dimmingView.alpha = 0.0
        
        containerView!.insertSubview(dimmingView, at: 0)
        
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: {
            context in
            self.dimmingView.alpha = 1.0
            }, completion: nil)
    }
    
    override func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()
        
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { context in
            self.dimmingView.alpha = 0.0
            }, completion:nil)
    }
    
    override func dismissalTransitionDidEnd(_ completed: Bool) {
        super.dismissalTransitionDidEnd(completed)
        
        dimmingView.removeFromSuperview()
    }
    
    override var frameOfPresentedViewInContainerView : CGRect {
        let height = containerView!.bounds.height
        let width = containerView!.bounds.width
        
        return CGRect(x: 0.0, y: 40.0, width: width, height: height-40.0)
    }
    
    override func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        
        dimmingView.frame = containerView!.bounds
    }
}
