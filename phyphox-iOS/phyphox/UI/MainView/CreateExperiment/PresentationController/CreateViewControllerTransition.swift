//
//  CreateViewControllerTransition.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.04.16.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import UIKit

final class CreateViewControllerTransition : NSObject, UIViewControllerAnimatedTransitioning {
    let presenting: Bool
    
    init(presenting: Bool) {
        self.presenting = presenting
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.75
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let fromViewC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)!
        let toViewC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)!
        
        
        let fromView = fromViewC.view
        let toView = toViewC.view

        if presenting {
            var f = fromView?.frame
            f?.size.height -= 40.0
            toView?.frame = f!
        }
        
        let center: CGPoint
        
        if presenting {
            center = (toView?.center)!
            toView?.center = CGPoint(x: center.x, y: (toView?.bounds.size.height)!)
            transitionContext.containerView.addSubview(toView!)
        }
        else {
            center = CGPoint(x: (toView?.center.x)!, y: (toView?.bounds.size.height)! + (fromView?.bounds.size.height)!)
        }
        
        UIView.animate(withDuration: self.transitionDuration(using: transitionContext), delay: 0.0, usingSpringWithDamping: 250.0, initialSpringVelocity: 7.0, options: [], animations: {
            if self.presenting {
                let v = fromViewC as! ScalableViewController
                
                v.viewControllerScale = 0.93
                
                var c = center
                c.y += 40.0
                
                toView?.center = c
            }
            else {
                let v = toViewC as! ScalableViewController
                
                v.viewControllerScale = 1.0
                
                fromView?.center = center
            }
            }, completion: { _ in
                if !self.presenting {
                    fromView?.removeFromSuperview()
                }
                
                transitionContext.completeTransition(true)
        })
    }
}
