//
//  CreateViewControllerTransitioningDelegate.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.04.16.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import UIKit

final class CreateViewControllerTransitioningDelegate : NSObject, UIViewControllerTransitioningDelegate {
    func presentationControllerForPresentedViewController(_ presented: UIViewController, presentingViewController presenting: UIViewController??, sourceViewController source: UIViewController) -> UIPresentationController? {
        return OverlayPresentationController(presentedViewController: presented, presenting: presenting!)
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController)-> UIViewControllerAnimatedTransitioning? {
        return CreateViewControllerTransition(presenting: true)
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return CreateViewControllerTransition(presenting: false)
    }
}
