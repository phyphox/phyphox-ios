//
//  ExperimentViewController.swift
//  phyphox
//
//  Created by Jonas Gessner on 08.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

final class ExperimentViewController: CollectionViewController {
    let experiment: Experiment
    
    let viewModules: [[UIView]]
    
    init(experiment: Experiment) {
        self.experiment = experiment
        
        var modules: [[UIView]] = []
        
        for collection in experiment.viewDescriptors {
            modules.append(ExperimentViewModuleFactory.createViews(collection))
        }
        
        self.viewModules = modules
        
        super.init(nibName: nil, bundle: nil)
        
        self.title = experiment.title
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override class var viewClass: CollectionView.Type {
        get {
            return ExperimentView.self
        }
    }
    
    override var customCells: [String: UICollectionViewCell.Type]? {
        get {
            return ["ModuleCell" : ExperimentViewModuleCollectionViewCell.self]
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItems = [UIBarButtonItem(barButtonSystemItem: .Play, target: self, action: "startExperiment"), UIBarButtonItem(barButtonSystemItem: .Action, target: self, action: "export")]
    }
    
    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return viewModules.count
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModules[section].count
    }
    
    override func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        return viewModules[indexPath.section][indexPath.row].sizeThatFits(viewSize)
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("ModuleCell", forIndexPath: indexPath) as! ExperimentViewModuleCollectionViewCell
        
        cell.module = viewModules[indexPath.section][indexPath.row]
        
        return cell
    }
    
    func export() {
        
    }
    
    func startExperiment() {
        
    }
}
