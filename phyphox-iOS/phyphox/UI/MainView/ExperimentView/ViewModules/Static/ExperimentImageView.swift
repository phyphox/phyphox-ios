//
//  ExperimentImageView.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 28.06.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentImageView: UIView {
    
    let descriptor: ImageViewDescriptor
    
    let imageView =  UIImageView()
    
    var imageHeight = 0.0
    var imageWidth = 0.0
    
    init(descriptor: ImageViewDescriptor) {
        self.descriptor = descriptor
    
        super.init(frame: .zero)
        
        let imageFromRes = loadImage()
        
        imageView.image = imageFromRes
        
        imageView.contentMode = .scaleToFill
        
        addSubview(imageView)
        
        imageHeight = imageFromRes.size.height
        imageWidth = imageFromRes.size.width
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        imageView.frame = bounds
        imageView.frame = CGRect(x: 10, y: 10, width: (frame.size.width - 20.0), height: (((frame.width - 20.0) / imageWidth) * imageHeight))
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
     
        var s = size
        s.width = size.width - 20.0
        s.height = imageView.sizeThatFits(s).height - 20.0
        return s
        
    }
    
    
    func loadImage() -> UIImage{
        if let imagePath = Bundle.main.path(forResource: "phyphox-experiments/res/hue", ofType: "png") {
            guard let image = UIImage(contentsOfFile: imagePath) else { return UIImage(resource: .rwth) }
            return image
        }
        return UIImage(resource: .rwth)
    }
}
