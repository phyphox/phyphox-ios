//
//  ExperimentHeaderView.swift
//  phyphox
//
//  Created by Jonas Gessner on 30.03.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
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
    
    var color: UIColor? {
        set {
            background.backgroundColor = newValue
            setNeedsLayout()
        }
        get {
            return background.backgroundColor
        }
    }
    
    var fontColor: UIColor? {
        set {
            label.textColor = newValue
            setNeedsLayout()
        }
        get {
            return label.textColor 
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        background.backgroundColor = kHighlightColor
        addSubview(background)
        
        label.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body)
        addSubview(label)
        
        label.textColor = kTextColor
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
      
        label.frame = CGRect(origin: CGPoint(x: 16.0, y: 8.0), size: CGSize(width: bounds.width-16.0, height: bounds.height-10.0))
        
        background.frame = CGRect(origin: CGPoint(x: 8.0, y: 8.0), size: CGSize(width: bounds.width-16.0, height: bounds.height-10.0))
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
    }
}
