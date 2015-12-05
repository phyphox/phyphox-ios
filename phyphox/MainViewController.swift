//
//  MainViewController.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import UIKit

class MainViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    var selfView: MainView {
        get {
            return view as! MainView
        }
    }
    
    override func loadView() {
        view = MainView()
        
        selfView.collectionView.registerClass(ExperimentCell.self, forCellWithReuseIdentifier: "ExperimentCell")
        selfView.collectionView.dataSource = self;
        selfView.collectionView.delegate = self;
    }
    
    //MARK: - UICollectionViewDataSource
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return ExperimentManager.sharedInstance().experimentCollections.count
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return ExperimentManager.sharedInstance().experimentCollections[section].experiments.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("ExperimentCell", forIndexPath: indexPath)
        
        return cell
    }
    
    //MARK: - UICollectionViewDelegate
}
