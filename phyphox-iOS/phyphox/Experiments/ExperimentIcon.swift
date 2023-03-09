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
            // It is fix for the icon background for contribution section header. When not used "if else case", then the icon is rendered as black
            // It renders black because when opening the app in light mode, it converts and adjust all the "white" color into black, as expected.
            if(color == UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)){
                imageView.backgroundColor = .white
            } else {
                imageView.backgroundColor = color
            }
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
