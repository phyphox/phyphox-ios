//
//  CollectionViewController.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

class CollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout  {
    
    var selfView: CollectionView {
        get {
            return view as! CollectionView
        }
    }
    
    private var targetViewSize: CGSize?
    
    /**
     Returns the current view size, or the target view size if a rotation is taking place. To be used for calculating cell width.
     */
    internal var viewSize: CGSize {
        get {
            if targetViewSize != nil {
                return targetViewSize!
            }
            else {
                return view.frame.size
            }
        }
    }
    
    override func loadView() {
        view = self.dynamicType.viewClass.init()
        
        if let cells = customCells {
            for (key, cellClass) in cells {
                selfView.collectionView.registerClass(cellClass, forCellWithReuseIdentifier: key)
            }
        }
        
        selfView.collectionView.dataSource = self;
        selfView.collectionView.delegate = self;
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        targetViewSize = size
        
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        self.selfView.collectionView.collectionViewLayout.invalidateLayout()
        
        coordinator.animateAlongsideTransition(nil) { (_) -> Void in
            self.targetViewSize = nil
        }
    }
    
    deinit {
        selfView.collectionView.dataSource = nil;
        selfView.collectionView.delegate = nil;
    }
    
    //MARK: - Override points
    
    internal class var viewClass: CollectionView.Type {
        get {
             return CollectionView.self
        }
    }
    
    internal var customCells: [String: UICollectionViewCell.Type]? {
        get {
            return nil
        }
    }
    
    //MARK: UICollectionViewDataSource
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 0
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 0
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        return CGSize.zero
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("OverrideThisMethod", forIndexPath: indexPath)
        
        return cell
    }
}
