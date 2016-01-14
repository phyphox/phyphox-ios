//
//  ExperimentViewModuleCollectionViewCell.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
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
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        module?.frame = self.contentView.bounds
    }
}
