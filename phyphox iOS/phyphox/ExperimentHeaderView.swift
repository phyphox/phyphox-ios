//
//  ExperimentHeaderView.swift
//  phyphox
//
//  Created by Jonas Gessner on 30.03.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
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
        
        label.textColor = UIColor.blackColor()// kHighlightColor
        
        separator.backgroundColor = UIColor.blackColor()
        separator.alpha = 0.1
        addSubview(separator)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let s = label.sizeThatFits(bounds.size)
        
        label.frame = CGRect(origin: CGPointMake(5.0, (bounds.size.height-s.height)/2.0), size: s)
        
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
