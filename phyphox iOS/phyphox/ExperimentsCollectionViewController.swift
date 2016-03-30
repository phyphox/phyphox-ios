//
//  ExperimentsCollectionViewController.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import UIKit

final class ExperimentsCollectionViewController: CollectionViewController {
    
    override class var viewClass: CollectionView.Type {
        get {
            return MainView.self
        }
    }
    
    override class var customCells: [String : UICollectionViewCell.Type]? {
        get {
            return ["ExperimentCell" : ExperimentCell.self]
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "phyphox"
    }
    
    //MARK: - UICollectionViewDataSource
    
    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return ExperimentManager.sharedInstance().experimentCollections.count
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return ExperimentManager.sharedInstance().experimentCollections[section].experiments!.count
    }
    
    override func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        return CGSizeMake(self.view.frame.size.width, 44.0)
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("ExperimentCell", forIndexPath: indexPath) as! ExperimentCell
        
        let collection = ExperimentManager.sharedInstance().experimentCollections[indexPath.section]
        let experiment = collection.experiments![indexPath.row]
        
        cell.setUpWithExperiment(experiment)
        
        return cell
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
