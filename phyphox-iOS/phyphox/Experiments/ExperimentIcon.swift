//
//  ExperimentIcon.swift
//  phyphox
//
//  Created by Jonas Gessner on 15.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import UIKit

enum ExperimentIcon: Equatable {
    case string(String)
    case image(UIImage)
    
    func generateResizableRepresentativeView(color: UIColor, fontColor: UIColor) -> UIView {
        switch self {
        case .image(let image):
            let imageView = UIImageView(image: image)
            imageView.backgroundColor = color
            return imageView
        case .string(let string):
            let label = UILabel()

            label.text = string
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = true
            label.font = UIFont.preferredFont(forTextStyle: .headline)

            label.textColor = fontColor
            label.backgroundColor = color

            return label
        }
    }

    static func == (lhs: ExperimentIcon, rhs: ExperimentIcon) -> Bool {
        switch lhs {
        case .image(let imageL):
            switch rhs {
            case .image(let imageR):
                return imageL.pngData() == imageR.pngData()
            default:
                return false
            }
        case .string(let stringL):
            switch rhs {
            case .string(let stringR):
                return stringL == stringR
            default:
                return false
            }
        }
    }
}
