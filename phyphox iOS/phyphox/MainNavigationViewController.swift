//
//  MainNavigationViewController.swift
//  phyphox
//
//  Created by Jonas Gessner on 08.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

class MainNavigationViewController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        hidesBarsOnSwipe = false
        
        self.navigationBar.translucent = true
        self.navigationBar.tintColor = kTextColor
        self.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: kTextColor]
        
        //barTintColor is set per view controller...
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
}
