//
//  ExperimentIcon.swift
//  phyphox
//
//  Created by Jonas Gessner on 15.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

final class ExperimentIcon {
    private let string: String?
    private let image: UIImage?
    
    init(string: String?, image: UIImage?) {
        self.string = string
        self.image = image
    }
    
    func generateResizableRepresentativeView() -> UIView {
        if image != nil {
            let imageView = UIImageView(image: image!)
            imageView.backgroundColor = kHighlightColor
            return imageView
        }
        else {
            let label = UILabel()
            
            label.text = string
            label.textAlignment = .Center
            label.adjustsFontSizeToFitWidth = true
            label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
            
            label.textColor = kTextColor
            label.backgroundColor = kHighlightColor
            
            return label
        }
    }
}
