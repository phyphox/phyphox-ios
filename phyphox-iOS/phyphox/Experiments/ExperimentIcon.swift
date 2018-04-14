//
//  ExperimentIcon.swift
//  phyphox
//
//  Created by Jonas Gessner on 15.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import UIKit

enum ExperimentIcon {
    case string(String)
    case image(UIImage)
    
    func generateResizableRepresentativeView() -> UIView {
        switch self {
        case .image(let image):
            let imageView = UIImageView(image: image)
            imageView.backgroundColor = kHighlightColor
            return imageView
        case .string(let string):
            let label = UILabel()

            label.text = string
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = true
            label.font = UIFont.preferredFont(forTextStyle: .headline)

            label.textColor = kTextColor
            label.backgroundColor = kHighlightColor

            return label
        }
    }
}
