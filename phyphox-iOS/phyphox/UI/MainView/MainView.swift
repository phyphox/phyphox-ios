//
//  MainView.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import UIKit

final class FixedBottomInsetCollectionView: UICollectionView {
    override var contentInset: UIEdgeInsets {
        get {
            return super.contentInset
        }
        set {
            var s = newValue
            s.bottom = 0.0
            super.contentInset = s
        }
    }
    
    override var scrollIndicatorInsets: UIEdgeInsets {
        get {
            return super.scrollIndicatorInsets
        }
        set {
            var s = newValue
            s.bottom = 0.0
            super.scrollIndicatorInsets = s
        }
    }
}

final class MainView: CollectionContainerView {
    override class var collectionViewClass: UICollectionView.Type {
        return FixedBottomInsetCollectionView.self
    }
    
    override init(frame: CGRect) {
     super.init(frame: frame)
        
        collectionView.backgroundColor = kBackgroundColor
    }
}
