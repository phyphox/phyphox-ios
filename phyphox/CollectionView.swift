//
//  CollectionView.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

class CollectionView: UIView {
    
    private(set) var collectionView: UICollectionView
    
    override init(frame: CGRect) {
        collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout())
        
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
