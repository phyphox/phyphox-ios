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
    
    private var exportSelectionView: ExperimentExportSetSelectionView?
    
    var selectedViewCollection: Int {
        didSet {
            if selectedViewCollection != oldValue {
                updateSelectedViewCollection()
            }
        }
    }
    
    func updateSelectedViewCollection() {
        titleView.prompt = experiment.viewDescriptors?[selectedViewCollection].localizedLabel
        titleView.sizeToFit()
        
        //Clear old modules, otherwise cell reuse will mess everything up...
        for cell in selfView.collectionView.visibleCells() as! [ExperimentViewModuleCollectionViewCell] {
            cell.module = nil
        }
        
        selfView.collectionView.reloadData()
    }
    
    func presentViewCollectionSelector() {
        if !titleView.promptButtonExtended {
            var titles: [String] = []
            
            for collection in experiment.viewDescriptors! {
                titles.append(collection.localizedLabel)
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
        
        if experiment.viewDescriptors != nil {
            for collection in experiment.viewDescriptors! {
                let m = ExperimentViewModuleFactory.createViews(collection)
                
                for module in m {
                    if let graph = module as? ExperimentGraphView {
                        graph.queue = experiment.queue
                    }
                }
                
                modules.append(m)
            }
        }
        
        viewModules = modules
        
        selectedViewCollection = 0
        
        super.init()
        
        self.title = experiment.localizedTitle
        
        updateSelectedViewCollection()
        
        if experiment.viewDescriptors?.count > 1 {
            titleView.promptAction = {[unowned self] () -> (Void) in
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
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController!.navigationBarHidden = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItems = [UIBarButtonItem(barButtonSystemItem: .Play, target: self, action: #selector(toggleExperiment)), UIBarButtonItem(barButtonSystemItem: .Action, target: self, action: #selector(action(_:)))]
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        experiment.stop()
        experiment.didBecomeInactive()
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
        
        (module as! ExperimentViewModuleProtocol).setNeedsUpdate()
        
        return cell
    }
    
    override func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 5.0
    }
    
    private func runExport() {
        let sets = exportSelectionView!.activeSets()!
        let format = exportSelectionView!.selectedFormat()
        
        let HUD = JGProgressHUD(style: .Dark)
        HUD.interactionType = .BlockTouchesOnHUDView
        HUD.textLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        
        HUD.showInView(navigationController!.view)
        
        dispatch_async(experiment.queue) { [unowned self] in
            if format.isCSV() {
                if sets.count == 1 {
                    let tmpFile = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent("phyphox-export.csv")
                    
                    do { try NSFileManager.defaultManager().removeItemAtPath(tmpFile) } catch {}
                    
                    let tmpFileURL = NSURL(fileURLWithPath: tmpFile)
                    
                    
                    let set = sets.first!
                    
                    let data = set.serialize(format)
                    
                    do {
                        try data!.writeToFile(tmpFile, options: [])
                        
                        mainThread {
                            let vc = UIActivityViewController(activityItems: [tmpFileURL], applicationActivities: nil)
                            self.navigationController!.presentViewController(vc, animated: true) {
                                HUD.dismiss()
                            }
                        }
                    }
                    catch let error {
                        print("File write error: \(error)")
                        mainThread {
                            HUD.indicatorView = JGProgressHUDErrorIndicatorView()
                            HUD.textLabel.text = "Could not create csv file"
                            HUD.dismissAfterDelay(3.0)
                        }
                    }
                }
                else {
                    let tmpFile = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent("phyphox-export.zip")
                    
                    do { try NSFileManager.defaultManager().removeItemAtPath(tmpFile) } catch {}
                    
                    let tmpFileURL = NSURL(fileURLWithPath: tmpFile)
                    
                    do {
                        let archive = try ZZArchive(URL: tmpFileURL, options: [ZZOpenOptionsCreateIfMissingKey : NSNumber(bool: true)])
                        
                        var entries = [ZZArchiveEntry]()
                        
                        for set in sets {
                            let data = set.serialize(format)
                            
                            entries.append(ZZArchiveEntry(fileName: set.localizedName + ".csv", compress: true, dataBlock: { error -> NSData? in
                                return data
                            }))
                        }
                        
                        try archive.updateEntries(entries)
                        
                        mainThread {
                            let vc = UIActivityViewController(activityItems: [tmpFileURL], applicationActivities: nil)
                            self.navigationController!.presentViewController(vc, animated: true) {
                                HUD.dismiss()
                            }
                        }
                        
                    }
                    catch let error {
                        print("Zip error: \(error)")
                        mainThread {
                            HUD.indicatorView = JGProgressHUDErrorIndicatorView()
                            HUD.textLabel.text = "Could not create csv file"
                            HUD.dismissAfterDelay(3.0)
                        }
                    }
                }
            }
            else {
                
            }
        }
    }
    
    private func showExport() {
        let alert = UIAlertController(title: "Export", message: "Select the data sets to export:", preferredStyle: .Alert)
        
        let exportAction = UIAlertAction(title: "Export", style: .Default, handler: { [unowned self] action in
            self.runExport()
            })
        
        if exportSelectionView == nil {
            exportSelectionView = ExperimentExportSetSelectionView(export: experiment.export!, translation: experiment.translation) { [unowned exportAction] available in
                exportAction.enabled = available
            }
        }
        
        alert.addAction(exportAction)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        
        alert.__pt__setAccessoryView(exportSelectionView!)
        
        self.navigationController!.presentViewController(alert, animated: true, completion: nil)
    }
    
    func action(item: UIBarButtonItem) {
        let alert = UIAlertController(title: "Actions", message: nil, preferredStyle: .ActionSheet)
        
        if experiment.export != nil {
            alert.addAction(UIAlertAction(title: "Export", style: .Default, handler: { action in
                self.showExport()
            }))
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = item
        }
        
        self.navigationController!.presentViewController(alert, animated: true, completion: nil)
    }
    
    func toggleExperiment() {
        if experiment.running {
            experiment.stop()
            self.navigationItem.rightBarButtonItems = [UIBarButtonItem(barButtonSystemItem: .Play, target: self, action: #selector(toggleExperiment)), UIBarButtonItem(barButtonSystemItem: .Action, target: self, action: #selector(action(_:)))]
        }
        else {
            experiment.start()
            self.navigationItem.rightBarButtonItems = [UIBarButtonItem(barButtonSystemItem: .Pause, target: self, action: #selector(toggleExperiment)), UIBarButtonItem(barButtonSystemItem: .Action, target: self, action: #selector(action(_:)))]
        }
    }
}
