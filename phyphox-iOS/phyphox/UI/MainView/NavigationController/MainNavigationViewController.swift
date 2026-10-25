//
//  MainNavigationViewController.swift
//  phyphox
//
//  Created by Jonas Gessner on 08.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit

class MainNavigationViewController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        hidesBarsOnSwipe = false
        
        self.navigationBar.tintColor = kTextColor
        self.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: kTextColor]
        
        self.interactivePopGestureRecognizer?.isEnabled = false
        
        //barTintColor is set per view controller...
    }

    //Each screen picks its status bar style: the experiment page's orange bar needs light content, the list follows the appearance
    override var childForStatusBarStyle: UIViewController? {
        return topViewController
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
}
