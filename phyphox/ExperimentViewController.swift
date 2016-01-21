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
    
    var selectedViewCollection: Int {
        didSet {
            if selectedViewCollection != oldValue {
                updateSelectedViewCollection()
            }
        }
    }
    
    func updateSelectedViewCollection() {
        titleView.prompt = experiment.viewDescriptors[selectedViewCollection].label
        
        //Clear old modules, otherwise cell reuse will mess everything up...
        for cell in selfView.collectionView.visibleCells() as! [ExperimentViewModuleCollectionViewCell] {
            cell.module = nil
        }
        
        selfView.collectionView.reloadData()
    }
    
    func presentViewCollectionSelector() {
        if !titleView.promptButtonExtended {
            var titles: [String] = []
            
            for collection in experiment.viewDescriptors {
                titles.append(collection.label)
            }
            
            let menu = PTDropDownMenu(items: titles)
            
            menu.buttonTappedBlock = {[unowned self](index: UInt) -> (Void) in
                self.selectedViewCollection = Int(index)
                self.dismissDropDownMenuIfVisible()
            }
            
            presentDropDownMenu(menu: menu)
        }
        else {
            dismissDropDownMenuIfVisible()
        }
    }
    
    init(experiment: Experiment) {
        self.experiment = experiment
        
        var modules: [[UIView]] = []
        
        for collection in experiment.viewDescriptors {
            modules.append(ExperimentViewModuleFactory.createViews(collection))
        }
        
        viewModules = modules

        selectedViewCollection = 0
        
        super.init()
        
        self.title = experiment.title
        
        updateSelectedViewCollection()
        
        if experiment.viewDescriptors.count > 1 {
            titleView.promptAction = {[unowned self](Void) -> (Void) in
                self.presentViewCollectionSelector()
            }
        }
    }
    
    override class var viewClass: CollectionView.Type {
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
        
        self.navigationItem.rightBarButtonItems = [UIBarButtonItem(barButtonSystemItem: .Play, target: self, action: "toggleExperiment"), UIBarButtonItem(barButtonSystemItem: .Action, target: self, action: "export")]
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        experiment.stop()
    }
    
    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModules[selectedViewCollection].count
    }
    
    override func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        let s = viewModules[selectedViewCollection][indexPath.row].sizeThatFits(self.view.frame.size)
        
        return CGSizeMake(collectionView.frame.size.width, s.height)
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("ModuleCell", forIndexPath: indexPath) as! ExperimentViewModuleCollectionViewCell
        
        let module = viewModules[selectedViewCollection][indexPath.row]
        
        cell.module = module
        
        if let graph = module as? ExperimentGraphView {
            graph.queue = experiment.queue
        }
        
        (module as! ExperimentViewModuleProtocol).setNeedsUpdate()
        
        return cell
    }
    
    override func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 5.0
    }
    
    func export() {
        
    }
    
    func toggleExperiment() {
        if experiment.running {
            experiment.stop()
            self.navigationItem.rightBarButtonItems = [UIBarButtonItem(barButtonSystemItem: .Play, target: self, action: "toggleExperiment"), UIBarButtonItem(barButtonSystemItem: .Action, target: self, action: "export")]
        }
        else {
            experiment.start()
            self.navigationItem.rightBarButtonItems = [UIBarButtonItem(barButtonSystemItem: .Pause, target: self, action: "toggleExperiment"), UIBarButtonItem(barButtonSystemItem: .Action, target: self, action: "export")]
        }
    }
}
