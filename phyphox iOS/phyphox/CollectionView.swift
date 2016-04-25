//
//  CollectionContainerView.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

class CollectionContainerView: UIView {
    class var collectionViewClass: UICollectionView.Type {
        return UICollectionView.self
    }
    
    private(set) var collectionView: UICollectionView
    
    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        
        collectionView = self.dynamicType.collectionViewClass.init(frame: CGRect.zero, collectionViewLayout: layout)
        
        super.init(frame: frame)
        
        addSubview(collectionView)
        
        self.backgroundColor = UIColor.whiteColor()
        collectionView.backgroundColor = UIColor.whiteColor()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        collectionView.frame = self.bounds
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }
}
