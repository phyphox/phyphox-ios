//
//  ExperimentImageView.swift
//  phyphox
//
//  Created by Sebastian Staacks on 08.05.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentImageView: UIView, DescriptorBoundViewModule, ResizingViewModule {
    let descriptor: ImageViewDescriptor
    let fontScale = UIFont.preferredFont(forTextStyle: .footnote).pointSize
    var image: UIImage?
    var imageView: UIView
    var onResize: (() -> Void)?

    //lightSrc/darkSrc swap the file with the interface mode (file format 1.21), so it is loaded again on a mode change
    private let resourceFolder: URL?
    private(set) var shownSrc: String

    private let sideMargins:CGFloat = 10.0
    private let verticalMargins:CGFloat = 10.0
    
    required init?(descriptor: ImageViewDescriptor, resourceFolder: URL?) {
        self.descriptor = descriptor
        self.resourceFolder = resourceFolder
        
        shownSrc = descriptor.src(dark: ExperimentImageView.isDarkMode)
        image = ExperimentImageView.loadImage(shownSrc, in: resourceFolder)
        imageView = ExperimentImageView.makeImageView(image)
        
        super.init(frame: .zero)
        
        addSubview(imageView)
        
        applyMode()
    }

    private static func loadImage(_ src: String, in resourceFolder: URL?) -> UIImage? {
        guard let file = Experiment.resolveResource(src, in: resourceFolder) else { return nil }
        return UIImage(contentsOfFile: file.path)
    }

    //A file that cannot be opened shows "Image not available" - there is no fallback to src
    private static func makeImageView(_ image: UIImage?) -> UIView {
        if let image = image {
            return UIImageView(image: image)
        } else {
            let tv = UITextView()
            tv.text = "Image not available"
            return tv
        }
    }

    private static var isDarkMode: Bool {
        if SettingBundleHelper.getAppMode() == Utility.LIGHT_MODE {
            return false
        } else if SettingBundleHelper.getAppMode() == Utility.DARK_MODE {
            return true
        } else {
            return UIScreen.main.traitCollection.userInterfaceStyle == .dark
        }
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
    
    func applyMode() {
        let dark = ExperimentImageView.isDarkMode
        let src = descriptor.src(dark: dark)
        if src != shownSrc {
            shownSrc = src
            image = ExperimentImageView.loadImage(src, in: resourceFolder)
            imageView.removeFromSuperview()
            imageView = ExperimentImageView.makeImageView(image)
            addSubview(imageView)
            //The box follows the image shown, which may have another aspect ratio. A view group places its children in
            //its own layoutSubviews, which an unchanged group size would not trigger.
            var ancestor: UIView? = self
            while let view = ancestor, !(view is UITableViewCell) {
                view.setNeedsLayout()
                ancestor = view.superview
            }
            onResize?()
        }
        applyGivenFilter(filter: dark ? descriptor.darkFilter : descriptor.lightFilter)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        if let image = image {
            let aspect = image.size.width / image.size.height
            let w = descriptor.scale * size.width - 2*sideMargins
            //A degenerate image makes aspect NaN/infinite; a NaN row height aborts the table view
            let h = (aspect.isFinite && aspect > 0) ? w / aspect : 0
            return CGSize(width: w, height: h + 2*verticalMargins)
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
        if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyMode()
        }
    }
}

extension ExperimentImageView: VisibilityControllableViewModule {
    var visibilityBuffer: DataBuffer? { descriptor.visibilityBuffer }
}
