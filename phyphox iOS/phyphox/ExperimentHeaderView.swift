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
    
    private let separator = UIView()
    
    var showSeparator = true {
        didSet {
            separator.hidden = !showSeparator
        }
    }

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
        
        label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        addSubview(label)
        
        label.textColor = kTextColor
        label.backgroundColor = kHighlightColor
        
        separator.backgroundColor = UIColor.blackColor()
        separator.alpha = 0.1
        addSubview(separator)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
      
        label.frame = CGRect(origin: CGPointMake(0.0, 1.0), size: CGSize(width: bounds.width, height: bounds.height-2.0))
        
        let separatorHeight = 1.0/UIScreen.mainScreen().scale
        
        separator.frame = CGRectMake(0.0, bounds.size.height-separatorHeight, bounds.size.width, separatorHeight)
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
    }
}
