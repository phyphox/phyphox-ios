//
//  ScalableViewController.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.04.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit

class ScalableViewController: UIViewController {
    final var viewControllerScale: CGFloat = 1.0 {
        didSet {
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }
    }
    
    let vc: UIViewController
    
    init(hostedVC: UIViewController) {
        vc = hostedVC
        
        super.init(nibName: nil, bundle: nil)
        
        addChild(vc)
        vc.view.frame = view.bounds
        view.addSubview(vc.view)
        vc.didMove(toParent: self)
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        vc.view.transform = CGAffineTransform.identity
        vc.view.frame = view.bounds
        vc.view.transform = CGAffineTransform(scaleX: viewControllerScale, y: viewControllerScale)
    }
}
