//
//  ExperimentCell.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import UIKit

class ExperimentCell: UICollectionViewCell {
    private var titleLabel: UILabel
    
    override init(frame: CGRect) {
        titleLabel = UILabel()
        
        super.init(frame: frame)
        
        contentView.addSubview(titleLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUpWithExperiment(experiment: Experiment) {
        titleLabel.text = experiment.title
        
        setNeedsLayout()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let s = titleLabel.sizeThatFits(CGRectInset(self.contentView.bounds, 10.0, 0.0) .size)
        
        titleLabel.frame = CGRectMake(5.0, (self.contentView.bounds.size.height-s.height)/2.0, s.width, s.height)
        
    }
}
