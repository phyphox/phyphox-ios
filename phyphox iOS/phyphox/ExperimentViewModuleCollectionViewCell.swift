//
//  ExperimentViewModuleCollectionViewCell.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//


import UIKit

class ExperimentViewModuleCollectionViewCell: UICollectionViewCell {
    var module: UIView? {
        willSet {
            if newValue != module && module != nil {
                module!.removeFromSuperview()
            }
        }
        
        didSet {
            if module != nil {
                contentView.addSubview(module!)
                setNeedsLayout() //Adding subview to contentview, so layoutSubviews isn't automatically triggered on self
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if module != nil {
            let s = module!.sizeThatFits(self.contentView.bounds.size)
            module!.frame = CGRectMake((self.contentView.bounds.size.width-s.width)/2.0, (self.contentView.bounds.size.height-s.height)/2.0, s.width, s.height)
        }
    }
}
