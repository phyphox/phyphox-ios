//
//  ExperimentHeaderView.swift
//  phyphox
//
//  Created by Jonas Gessner on 30.03.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

final class ExperimentHeaderView: UICollectionReusableView {
    private let label = UILabel()
    
    private let background = UIView()

    var title: String? {
        set {
            label.text = newValue
            setNeedsLayout()
        }
        get {
            return label.text
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        background.backgroundColor = kHighlightColor
        addSubview(background)
        
        label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        addSubview(label)
        
        label.textColor = kTextColor
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
      
        label.frame = CGRect(origin: CGPointMake(16.0, 8.0), size: CGSize(width: bounds.width-16.0, height: bounds.height-10.0))
        
        background.frame = CGRect(origin: CGPointMake(8.0, 8.0), size: CGSize(width: bounds.width-16.0, height: bounds.height-10.0))
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
    }
}
