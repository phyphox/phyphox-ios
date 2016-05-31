//
//  ExperimentViewController.swift
//  phyphox
//
//  Created by Jonas Gessner on 08.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit
import GCDWebServers

final class ExperimentViewController: CollectionViewController {
    private let modules: [UIView]
    
    init(modules: [UIView]) {
        self.modules = modules
        super.init()
    }
    
    override class var viewClass: CollectionContainerView.Type {
        get {
            return ExperimentView.self
        }
    }
    
    override class var customCells: [String: UICollectionViewCell.Type]? {
        get {
            return ["ModuleCell" : ExperimentViewModuleCollectionViewCell.self]
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        selfView!.collectionView.backgroundColor = kBackgroundColor
    }
    
    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return modules.count
    }
    
    override func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        let s = modules[indexPath.row].sizeThatFits(self.view.frame.size)
        
        return CGSizeMake(collectionView.frame.size.width, s.height)
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAtIndex section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 10.0, left: 0.0, bottom: 0.0, right: 0.0)
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("ModuleCell", forIndexPath: indexPath) as! ExperimentViewModuleCollectionViewCell
        
        let module = modules[indexPath.row]
        
        cell.module = module
        
        (module as! ExperimentViewModuleProtocol).setNeedsUpdate()
        
        return cell
    }
    
    override func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 5.0
    }
}
