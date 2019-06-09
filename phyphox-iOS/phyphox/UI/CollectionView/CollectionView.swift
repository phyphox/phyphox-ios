//
//  CollectionContainerView.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit

class CollectionContainerView: UIView {
    class var collectionViewClass: UICollectionView.Type {
        return UICollectionView.self
    }
    
    private(set) var collectionView: UICollectionView
    
    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        
        collectionView = type(of: self).collectionViewClass.init(frame: CGRect.zero, collectionViewLayout: layout)
        
        super.init(frame: frame)
        
        addSubview(collectionView)
        
        self.backgroundColor = UIColor.white
        collectionView.backgroundColor = UIColor.white
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        collectionView.frame = self.bounds
        
        if #available(iOS 11, *) {
            let insets = self.safeAreaInsets
            collectionView.contentInset = UIEdgeInsets(top: 0, left: insets.left, bottom: 0, right: insets.right)
        }
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }
}
