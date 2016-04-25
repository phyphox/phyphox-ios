//
//  ExperimentsCollectionViewController.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
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
    
    override class var viewClass: CollectionContainerView.Type {
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
        
        let infoButton = UIButton(type: .InfoLight)
        infoButton.addTarget(self, action: #selector(infoPressed), forControlEvents: .TouchUpInside)
        infoButton.sizeToFit()
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: infoButton)
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: #selector(createNewExpriment))
    }
    
    private func showOpenSourceLicenses() {
        let alert = UIAlertController(title: "Open Source Licenses", message: PTFile.stringWithContentsOfFile(NSBundle.mainBundle().pathForResource("Licenses", ofType: "ptf")!), preferredStyle: .Alert)
        
        alert.addAction(UIAlertAction(title: "Done", style: .Cancel, handler: nil))
        
        navigationController!.presentViewController(alert, animated: true, completion: nil)
    }
    
    func infoPressed() {
        let alert = UIAlertController(title: "Information", message: "Things\n\niOS app: Jonas Gessner\n\nAndroid app, creator:\nSebastian Kuhlen\n\nRWTH Aachen.", preferredStyle: .Alert)
        
        alert.addAction(UIAlertAction(title: "Open Source Licenses", style: .Default, handler: { [unowned self] _ in
            self.showOpenSourceLicenses()
        }))
        
        alert.addAction(UIAlertAction(title: "Done", style: .Cancel, handler: nil))
        
        navigationController!.presentViewController(alert, animated: true, completion: nil)
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
        
        if iPad {
            nav.modalPresentationStyle = .FormSheet
        }
        else {
            nav.transitioningDelegate = overlayTransitioningDelegate
            nav.modalPresentationStyle = .Custom
        }
        
        navigationController!.parentViewController!.presentViewController(nav, animated: true, completion: nil)
    }
    
    //MARK: - UICollectionViewDataSource
    
    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return ExperimentManager.sharedInstance().experimentCollections.count
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return ExperimentManager.sharedInstance().experimentCollections[section].experiments!.count
    }
    
    override func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        var cells: CGFloat = 1.0
        
        var width = self.view.frame.size.width
        
        while self.view.frame.size.width/(cells+1.0) >= minCellWidth {
            cells += 1.0
            width = self.view.frame.size.width/cells
        }
        
        cellsPerRow = Int(cells)
        
        return CGSizeMake(width, 44.0)
    }
    
    private func showDeleteConfirmationForExperiment(experiment: Experiment, button: UIButton) {
        let alert = UIAlertController(title: "Confirm Delete?", message: "This cannot be undone", preferredStyle: .ActionSheet)
        
        alert.addAction(UIAlertAction(title: "Delete \(experiment.localizedTitle)", style: .Destructive, handler: { [unowned self] action in
            do {
                try ExperimentManager.sharedInstance().deleteExperiment(experiment)
            }
            catch let error as NSError {
                let hud = JGProgressHUD(style: .Dark)
                hud.interactionType = .BlockTouchesOnHUDView
                hud.indicatorView = JGProgressHUDErrorIndicatorView()
                hud.textLabel.text = "Failed to delete experiment: \(error.localizedDescription)"
                
                hud.showInView(self.view)
                
                hud.dismissAfterDelay(3.0)
            }
            }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.navigationController!.view
            popover.sourceRect = button.convertRect(button.bounds, toView: self.navigationController!.view)
        }
        
        presentViewController(alert, animated: true, completion: nil)
    }
    
    private func showOptionsForExperiment(experiment: Experiment, button: UIButton) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        
        alert.addAction(UIAlertAction(title: "Delete", style: .Destructive, handler: { [unowned self] action in
            self.showDeleteConfirmationForExperiment(experiment, button: button)
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.navigationController!.view
            popover.sourceRect = button.convertRect(button.bounds, toView: self.navigationController!.view)
        }
        
        presentViewController(alert, animated: true, completion: nil)
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("ExperimentCell", forIndexPath: indexPath) as! ExperimentCell
        
        let collection = ExperimentManager.sharedInstance().experimentCollections[indexPath.section]
        let experiment = collection.experiments![indexPath.row]
        
        cell.experiment = experiment
        
        cell.showSideSeparator = cellsPerRow > 1 && (indexPath.row % cellsPerRow) != cellsPerRow-1
        
        if collection.customExperiments {
            cell.showsOptionsButton = true
            cell.optionsButtonCallback = { [unowned experiment, unowned self] button in
                self.showOptionsForExperiment(experiment, button: button)
            }
        }
        else {
            cell.showsOptionsButton = false
            cell.optionsButtonCallback = nil
        }
        
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
