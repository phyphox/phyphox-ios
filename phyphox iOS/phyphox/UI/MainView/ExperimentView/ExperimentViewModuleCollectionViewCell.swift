//
//  ExperimentViewModuleCollectionViewCell.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

final class ExperimentViewModuleCollectionViewCell: UICollectionViewCell {
    var module: ExperimentViewModuleView? {
        willSet {
            if newValue !== module {
                module?.removeFromSuperview()
            }
        }
        
        didSet {
            if let module = module {
                contentView.addSubview(module)
                setNeedsLayout() //Adding subview to contentview, so layoutSubviews isn't automatically triggered on self
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if let module = module {
            let size = module.sizeThatFits(self.contentView.bounds.size)

            let origin = CGPoint(x: (contentView.bounds.size.width - size.width)/2.0, y: (contentView.bounds.size.height - size.height)/2.0)

            module.frame = CGRect(origin: origin, size: size)
        }
    }
}
