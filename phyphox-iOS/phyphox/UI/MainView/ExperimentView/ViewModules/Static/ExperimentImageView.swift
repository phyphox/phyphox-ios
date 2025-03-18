//
//  ExperimentImageView.swift
//  phyphox
//
//  Created by Sebastian Staacks on 08.05.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentImageView: UIView, DescriptorBoundViewModule {
    let descriptor: ImageViewDescriptor
    let fontScale = UIFont.preferredFont(forTextStyle: .footnote).pointSize
    var image: UIImage?
    var imageView: UIView

    private let sideMargins:CGFloat = 10.0
    private let verticalMargins:CGFloat = 10.0
    
    required init?(descriptor: ImageViewDescriptor, resourceFolder: URL?) {
        self.descriptor = descriptor
        
        if let resourceFolder = resourceFolder {
            let src = resourceFolder.appendingPathComponent(descriptor.src).path
            image = UIImage(contentsOfFile: src)
        }
        
        if let image = image {
            let iv = UIImageView(image: image)
            imageView = iv
        } else {
            let tv = UITextView()
            tv.text = "Image not available"
            imageView = tv
        }
        
        super.init(frame: .zero)
        
        addSubview(imageView)
        
        applyFilter()
    }
    
    func applyGivenFilter(filter: ImageViewElementDescriptor.Filter) {
        if let image = image {
            switch filter {
                
            case .none:
                (imageView as! UIImageView).image = image
            case .invert:
                let renderer = UIGraphicsImageRenderer(size: image.size)
                (imageView as! UIImageView).image = renderer.image { (context) in
                    let rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
                    image.draw(in: rect)
                    UIColor(white: 1.0, alpha: 1.0).setFill()
                    context.fill(rect, blendMode: .difference)
                    image.draw(in: rect, blendMode: .destinationIn, alpha: 1.0)
                }
            }
        }
    }
    
    func applyFilter() {
        guard #available(iOS 13.0, *) else {
            applyGivenFilter(filter: descriptor.lightFilter)
            return
        }
        if SettingBundleHelper.getAppMode() == Utility.LIGHT_MODE {
            applyGivenFilter(filter: descriptor.lightFilter)
        } else if SettingBundleHelper.getAppMode() == Utility.DARK_MODE {
            applyGivenFilter(filter: descriptor.darkFilter)
        } else {
            if UIScreen.main.traitCollection.userInterfaceStyle == .dark {
                applyGivenFilter(filter: descriptor.darkFilter)
            } else {
                applyGivenFilter(filter: descriptor.lightFilter)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        if let image = image {
            let aspect = image.size.width / image.size.height
            let w = descriptor.scale * size.width - 2*sideMargins
            return CGSize(width: w, height:  w / aspect + 2*verticalMargins)
        } else {
            return (imageView as! UITextView).sizeThatFits(CGSize(width: size.width - 2*sideMargins, height: size.height))
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds.insetBy(dx: 0, dy: verticalMargins)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                applyFilter()
            }
        }
    }
}
