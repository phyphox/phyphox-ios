//
//  CreateViewControllerTransitioningDelegate.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.04.16.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

final class CreateViewControllerTransitioningDelegate : NSObject, UIViewControllerTransitioningDelegate {
    func presentationControllerForPresentedViewController(presented: UIViewController, presentingViewController presenting: UIViewController, sourceViewController source: UIViewController) -> UIPresentationController? {
        return OverlayPresentationController(presentedViewController: presented, presentingViewController: presenting)
    }
    
    func animationControllerForPresentedController(presented: UIViewController, presentingController presenting: UIViewController, sourceController source: UIViewController)-> UIViewControllerAnimatedTransitioning? {
        return CreateViewControllerTransition(presenting: true)
    }
    
    func animationControllerForDismissedController(dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return CreateViewControllerTransition(presenting: false)
    }
}
