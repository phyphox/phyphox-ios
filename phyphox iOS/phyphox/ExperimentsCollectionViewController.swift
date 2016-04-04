//
//  ExperimentsCollectionViewController.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import UIKit

private let minCellWidth: CGFloat = 320.0

final class ExperimentsCollectionViewController: CollectionViewController {
    private var cellsPerRow: Int = 1 {
        didSet {
            if cellsPerRow != oldValue {
                updateRowSeparators()
            }
        }
    }
    
    override class var viewClass: CollectionView.Type {
        return MainView.self
    }
    
    override class var customCells: [String : UICollectionViewCell.Type]? {
        return ["ExperimentCell" : ExperimentCell.self]
    }
    
    override class var customHeaders: [String : UICollectionReusableView.Type]? {
        return ["Header" : ExperimentHeaderView.self]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "phyphox"
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(reload), name: ExperimentsReloadedNotification, object: nil)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: #selector(createNewExpriment))
    }

    func reload() {
        selfView.collectionView.reloadData()
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    let overlayTransitioningDelegate = CreateViewControllerTransitioningDelegate()
    
    func createNewExpriment() {
        let vc = CreateExperimentViewController()
        let nav = UINavigationController(rootViewController: vc)
        
        nav.transitioningDelegate = overlayTransitioningDelegate
        nav.modalPresentationStyle = .Custom
        
        presentViewController(nav, animated: true, completion: nil)
    }
    
    //MARK: - UICollectionViewDataSource
    
    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return ExperimentManager.sharedInstance().experimentCollections.count
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return ExperimentManager.sharedInstance().experimentCollections[section].experiments!.count
    }
    
    override func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        var cells = 1
        
        var width = self.view.frame.size.width
        
        while width/2.0 >= minCellWidth {
            width /= 2.0
            cells *= 2
        }
        
        cellsPerRow = cells
        
        return CGSizeMake(width, 44.0)
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("ExperimentCell", forIndexPath: indexPath) as! ExperimentCell
        
        let collection = ExperimentManager.sharedInstance().experimentCollections[indexPath.section]
        let experiment = collection.experiments![indexPath.row]
        
        cell.experiment = experiment
        
        cell.showSideSeparator = cellsPerRow > 1 && (indexPath.row % cellsPerRow) != cellsPerRow-1
        
//        cell.showSeparator = indexPath.row < collection.experiments!.count-1
        
        return cell
    }
    
    func updateRowSeparators() {
        for indexPath in self.selfView.collectionView.indexPathsForVisibleItems() {
            let cell = self.selfView.collectionView.cellForItemAtIndexPath(indexPath) as! ExperimentCell
            
            cell.showSideSeparator = self.cellsPerRow > 1 && (indexPath.row % self.cellsPerRow) != self.cellsPerRow-1
        }
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSizeMake(self.view.frame.size.width, 28.0)
    }
    
    func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {
        if kind == UICollectionElementKindSectionHeader {
            let view = collectionView.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: "Header", forIndexPath: indexPath) as! ExperimentHeaderView
            
            let collection = ExperimentManager.sharedInstance().experimentCollections[indexPath.section]
            
            view.title = collection.title
            
            return view
        }
        
        assert(false, "Invalid supplementary view: \(kind)")
    }
    
    //MARK: - UICollectionViewDelegate
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let experiment = ExperimentManager.sharedInstance().experimentCollections[indexPath.section].experiments![indexPath.row]
        
        if let sensors = experiment.sensorInputs {
            for sensor in sensors {
                do {
                    try sensor.verifySensorAvailibility()
                }
                catch SensorError.SensorUnavailable(let type) {
                    let controller = UIAlertController(title: "Sensor Unavailable", message: "The \(type) sensor is not available on this device.", preferredStyle: .Alert)
                    
                    controller.addAction(UIAlertAction(title: "OK", style: .Cancel, handler:nil))
                    
                    presentViewController(controller, animated: true, completion: nil)
                    
                    return
                }
                catch {}
            }
        }
        
        let vc = ExperimentViewController(experiment: experiment)
        
        var denied = false
        var showing = false
        
        experiment.willGetActive {
            denied = true
            if showing {
                self.navigationController!.popViewControllerAnimated(true)
            }
        }
        
        if !denied {
            navigationController!.pushViewController(vc, animated: true)
            showing = true
        }
    }
}
