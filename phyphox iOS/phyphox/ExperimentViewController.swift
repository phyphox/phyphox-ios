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

final class ExperimentViewController: CollectionViewController, ExperimentWebServerDelegate {
    let experiment: Experiment
    
    let webServer: ExperimentWebServer
    private let viewModules: [[UIView]]
    
    var timerRunning: Bool {
        return experimentRunTimer != nil
    }
    
    var remainingTimerTime: Double {
        return experimentRunTimer?.fireDate.timeIntervalSinceNow ?? 0.0
    }
    
    private var timerDelayString: String?
    private var timerDurationString: String?
    private var timerEnabled = false
    
    private var experimentStartTimer: NSTimer?
    private var experimentRunTimer: NSTimer?
    
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
        self.webServer = ExperimentWebServer(experiment: experiment)
        
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
            titleView.promptAction = { [unowned self] in
                self.presentViewCollectionSelector()
            }
        }
        
        webServer.delegate = self
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
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController!.navigationBarHidden = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        selfView.collectionView.backgroundColor = kBackgroundColor
        
        let actionItem = UIBarButtonItem(image: generateDots(20.0), landscapeImagePhone: generateDots(15.0), style: .Plain, target: self, action: #selector(action(_:)))
        actionItem.imageInsets = UIEdgeInsets(top: 0.0, left: -25.0, bottom: 0.0, right: 0.0)
        
        self.navigationItem.rightBarButtonItems = [actionItem, UIBarButtonItem(barButtonSystemItem: .Play, target: self, action: #selector(toggleExperiment))]
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        tearDownWebServer()
        
        experimentStartTimer?.invalidate()
        experimentStartTimer = nil
        
        experimentRunTimer?.invalidate()
        experimentRunTimer = nil
        
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
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAtIndex section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 10.0, left: 0.0, bottom: 0.0, right: 0.0)
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
    
    private func launchWebServer() {
        if !webServer.start() {
            let hud = JGProgressHUD(style: .Dark)
            hud.interactionType = .BlockTouchesOnHUDView
            hud.indicatorView = JGProgressHUDErrorIndicatorView()
            hud.textLabel.text = "Failed to initialize HTTP server"
            
            hud.showInView(self.view)
            
            hud.dismissAfterDelay(3.0)
        }
        else {
            let al = UIAlertController(title: NSLocalizedString("remoteServer", comment: ""), message: NSLocalizedString("remoteServerActive", comment: "")+"\n\(webServer.server!.serverURL)", preferredStyle: .Alert)
            
            al.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .Cancel, handler: nil))
            
            self.navigationController!.presentViewController(al, animated: true, completion: nil)
        }
    }
    
    private func tearDownWebServer() {
        webServer.stop()
    }
    
    private func toggleWebServer() {
        if webServer.running {
            tearDownWebServer()
        }
        else {
            launchWebServer()
        }
    }
    
    private func runExportFromActionSheet() {
        let sets = exportSelectionView!.activeSets()!
        let format = exportSelectionView!.selectedFormat()
        
        let HUD = JGProgressHUD(style: .Dark)
        HUD.interactionType = .BlockTouchesOnHUDView
        HUD.textLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        
        HUD.showInView(navigationController!.view)
        
        runExport(sets, format: format) { error, URL in
            if error != nil {
                HUD.indicatorView = JGProgressHUDErrorIndicatorView()
                HUD.textLabel.text = error!.localizedDescription
                HUD.dismissAfterDelay(3.0)
            }
            else {
                let vc = UIActivityViewController(activityItems: [URL!], applicationActivities: nil)
                
                vc.completionWithItemsHandler = { _ in
                    do { try NSFileManager.defaultManager().removeItemAtURL(URL!) } catch {}
                }
                
                self.navigationController!.presentViewController(vc, animated: true) {
                    HUD.dismiss()
                }
            }
        }
    }
    
    func runExport(sets: [ExperimentExportSet], format: ExportFileFormat, completion: (NSError?, NSURL?) -> Void) {
        self.experiment.export!.runExport(format, selectedSets: sets) { (errorMessage, fileURL) in
            if let error = errorMessage {
                completion(NSError(domain: NSURLErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: error]), nil)
            }
            else if let URL = fileURL {
                completion(nil, URL)
            }
        }
    }
    
    private func showExport() {
        let alert = UIAlertController(title: NSLocalizedString("export", comment: ""), message: "Select the data sets to export:", preferredStyle: .Alert)
        
        let exportAction = UIAlertAction(title: NSLocalizedString("export", comment: ""), style: .Default, handler: { [unowned self] action in
            self.runExportFromActionSheet()
            })
        
        if exportSelectionView == nil {
            exportSelectionView = ExperimentExportSetSelectionView(export: experiment.export!, translation: experiment.translation) { [unowned exportAction] available in
                exportAction.enabled = available
            }
        }
        
        alert.addAction(exportAction)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .Cancel, handler: nil))
        
        alert.__pt__setAccessoryView(exportSelectionView!)
        
        self.navigationController!.presentViewController(alert, animated: true, completion: nil)
    }
    
    private func showTimerOptions() {
        let alert = UIAlertController(title: NSLocalizedString("timedRunDialogTitle", comment: ""), message: nil, preferredStyle: .Alert)
        
        alert.addTextFieldWithConfigurationHandler { [unowned self] textField in
            textField.keyboardType = .DecimalPad
            textField.placeholder = NSLocalizedString("timedRunStartDelay", comment: "")
            
            textField.text = self.timerDelayString
        }
        
        alert.addTextFieldWithConfigurationHandler { [unowned self] textField in
            textField.keyboardType = .DecimalPad
            textField.placeholder = NSLocalizedString("timedRunStopDelay", comment: "")
            
            textField.text = self.timerDurationString
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("enableTimedRun", comment: ""), style: .Default, handler: { [unowned self, unowned alert] action in
            self.timerEnabled = true
            
            self.timerDelayString = alert.textFields!.first!.text
            self.timerDurationString = alert.textFields!.last!.text
            }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("disableTimedRun", comment: ""), style: .Cancel, handler: { [unowned self, unowned alert] action in
            self.timerEnabled = false
            
            self.timerDelayString = alert.textFields!.first!.text
            self.timerDurationString = alert.textFields!.last!.text
            }))
        
        self.navigationController!.presentViewController(alert, animated: true, completion: nil)
    }
    
    func action(item: UIBarButtonItem) {
        let alert = UIAlertController(title: NSLocalizedString("actions", comment: ""), message: nil, preferredStyle: .ActionSheet)
        
        if experiment.export != nil {
            alert.addAction(UIAlertAction(title: NSLocalizedString("export", comment: ""), style: .Default, handler: { [unowned self] action in
                self.showExport()
                }))
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("timedRun", comment: ""), style: .Default, handler: { [unowned self] action in
            self.showTimerOptions()
            }))
        
        alert.addAction(UIAlertAction(title: (webServer.running ? NSLocalizedString("disableRemoteServer", comment: "") : NSLocalizedString("enableRemoteServer", comment: "")), style: .Default, handler: { [unowned self] action in
            self.toggleWebServer()
            }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("show_description", comment: ""), style: .Default, handler: { [unowned self] action in
            let al = UIAlertController(title: self.experiment.localizedTitle, message: self.experiment.localizedDescription, preferredStyle: .Alert)
            
            al.addAction(UIAlertAction(title: NSLocalizedString("close", comment: ""), style: .Cancel, handler: nil))
            
            self.navigationController!.presentViewController(al, animated: true, completion: nil)
            }))
        
        if experiment.hasStarted {
            alert.addAction(UIAlertAction(title: NSLocalizedString("share", comment: ""), style: .Default, handler: { [unowned self] action in
                var s = self.selfView.collectionView.contentSize
                let inset = self.selfView.collectionView.contentInset.top
                
                if self.selfView.collectionView.frame.height-inset < s.height {
                    s.height = self.selfView.collectionView.frame.height-inset
                }
                
                UIGraphicsBeginImageContextWithOptions(s, true, 0.0)
                
                self.selfView.collectionView.drawViewHierarchyInRect(CGRect(origin: CGPointMake(0.0, -inset), size: self.selfView.collectionView.frame.size), afterScreenUpdates: false)
                
                let img = UIGraphicsGetImageFromCurrentImageContext()
                
                UIGraphicsEndImageContext()
                
                let HUD = JGProgressHUD(style: .Dark)
                HUD.interactionType = .BlockTouchesOnHUDView
                HUD.textLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
                
                HUD.showInView(self.navigationController!.view)
                
                let vc = UIActivityViewController(activityItems: [img], applicationActivities: nil)
                
                self.navigationController!.presentViewController(vc, animated: true) {
                    HUD.dismiss()
                }
                }))
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("clear_data", comment: ""), style: .Destructive, handler: { [unowned self] action in
                self.clearData()
                }))
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .Cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = item
        }
        
        self.navigationController!.presentViewController(alert, animated: true, completion: nil)
    }
    
    func stopTimerFired() {
        stopExperiment()
    }
    
    func startTimerFired() {
        actuallyStartExperiment()
        
        experimentStartTimer!.invalidate()
        experimentStartTimer = nil
        
        let d = Double(timerDurationString ?? "0") ?? 0.0
        let i = Int(d)
        
        var items = navigationItem.rightBarButtonItems!
        
        let label = items.last!.customView! as! UILabel
        
        label.text = "\(i)"
        label.sizeToFit()
        
        items.removeLast()
        items.append(UIBarButtonItem(customView: label))
        
        navigationItem.rightBarButtonItems = items
        
        func updateT() {
            if self.experimentRunTimer != nil {
                let t = Int(round(self.experimentRunTimer!.fireDate.timeIntervalSinceNow))
                
                after(1.0, closure: {
                    updateT()
                })
                
                label.text = "\(t)"
                label.sizeToFit()
                
                var items = navigationItem.rightBarButtonItems!
                
                items.removeLast()
                items.append(UIBarButtonItem(customView: label))
                
                navigationItem.rightBarButtonItems = items
            }
        }
        
        after(1.0, closure: {
            updateT()
        })
        
        experimentRunTimer = NSTimer.scheduledTimerWithTimeInterval(d, target: self, selector: #selector(stopTimerFired), userInfo: nil, repeats: false)
    }
    
    func startExperiment() {
        if !experiment.running {
            if experimentStartTimer != nil {
                experimentStartTimer!.invalidate()
                experimentStartTimer = nil
                
                var items = navigationItem.rightBarButtonItems!
                
                items.removeLast()
                
                navigationItem.rightBarButtonItems = items
                
                return
            }
            
            if timerEnabled {
                let d = Double(timerDelayString ?? "0") ?? 0.0
                let i = Int(d)
                
                var items = navigationItem.rightBarButtonItems!
                
                let label = UILabel()
                label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleCaption1)
                label.textColor = kHighlightColor
                label.text = "\(i)"
                label.sizeToFit()
                
                items.append(UIBarButtonItem(customView: label))
                
                navigationItem.rightBarButtonItems = items
                
                func updateT() {
                    if self.experimentStartTimer != nil {
                        let t = Int(round(self.experimentStartTimer!.fireDate.timeIntervalSinceNow))
                        
                        after(1.0, closure: {
                            updateT()
                        })
                        
                        label.text = "\(t)"
                        label.sizeToFit()
                        
                        var items = navigationItem.rightBarButtonItems!
                        
                        items.removeLast()
                        items.append(UIBarButtonItem(customView: label))
                        
                        navigationItem.rightBarButtonItems = items
                    }
                }
                
                after(1.0, closure: {
                    updateT()
                })
                
                experimentStartTimer = NSTimer.scheduledTimerWithTimeInterval(d, target: self, selector: #selector(startTimerFired), userInfo: nil, repeats: false)
            }
            else {
                actuallyStartExperiment()
            }
        }
    }
    
    func actuallyStartExperiment() {
        experiment.start()
        var items = navigationItem.rightBarButtonItems!
        
        items[1] = UIBarButtonItem(barButtonSystemItem: .Pause, target: self, action: #selector(toggleExperiment))
        
        navigationItem.rightBarButtonItems = items
    }
    
    func stopExperiment() {
        if experiment.running {
            var items = navigationItem.rightBarButtonItems!
            
            if experimentRunTimer != nil {
                experimentRunTimer!.invalidate()
                experimentRunTimer = nil
                
                items.removeLast()
            }
            
            experiment.stop()
            
            items[1] = UIBarButtonItem(barButtonSystemItem: .Play, target: self, action: #selector(toggleExperiment))
            
            navigationItem.rightBarButtonItems = items
        }
    }
    
    func toggleExperiment() {
        if experiment.running {
            stopExperiment()
        }
        else {
            startExperiment()
        }
    }
    
    func clearData() {
        self.stopExperiment()
        self.experiment.clear()
        
        for section in self.viewModules {
            for view in section {
                if let graphView = view as? ExperimentGraphView {
                    graphView.clearAllDataSets()
                }
            }
        }
    }
}
