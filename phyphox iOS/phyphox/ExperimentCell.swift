//
//  ExperimentCell.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import UIKit

class ExperimentCell: UICollectionViewCell {
    private let titleLabel = UILabel()
    private let separator = UIView()
    
    var showSeparator = true {
        didSet {
            separator.hidden = !showSeparator
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        titleLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleCaption1)
        
        separator.backgroundColor = UIColor.blackColor()
        separator.alpha = 0.1
        
        contentView.backgroundColor = UIColor.whiteColor()
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(separator)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUpWithExperiment(experiment: Experiment) {
        titleLabel.text = experiment.localizedTitle
        
        setNeedsLayout()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let s = titleLabel.sizeThatFits(CGRectInset(self.contentView.bounds, 10.0, 0.0) .size)
        
        titleLabel.frame = CGRectMake(5.0, (self.contentView.bounds.size.height-s.height)/2.0, s.width, s.height)
        
        let separatorHeight = 1.0/UIScreen.mainScreen().scale
        
        separator.frame = CGRectMake(0.0, contentView.bounds.size.height-separatorHeight, contentView.bounds.size.width, separatorHeight)
    }
}
