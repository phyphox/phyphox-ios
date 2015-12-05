//
//  MainView.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import UIKit

class MainView: UIView {
    
    private(set) var collectionView: UICollectionView
    
    override init(frame: CGRect) {
        collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout())
        
        super.init(frame: frame)
        
        self.addSubview(collectionView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        collectionView.frame = self.bounds
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }
}
