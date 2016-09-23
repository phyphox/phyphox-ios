//
//  ExperimentPageViewController.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 30.05.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation
import GCDWebServers

final class ExperimentPageViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, ExperimentWebServerDelegate, UIPopoverPresentationControllerDelegate, UIGestureRecognizerDelegate {
    var segControl: UISegmentedControl? = nil
    
    let pageViewControler: UIPageViewController = UIPageViewController(transitionStyle: UIPageViewControllerTransitionStyle.Scroll, navigationOrientation: UIPageViewControllerNavigationOrientation.Horizontal, options: nil)
    
    var serverLabel: UILabel? = nil
    
    let experiment: Experiment
    
    var experimentViewControllers: [ExperimentViewController] = []
    
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
        segControl?.selectedSegmentIndex = selectedViewCollection
        
        for (index, collection) in viewModules.enumerate() {
            for module in collection {
                if var proto = module as? ExperimentViewModuleProtocol {
                    if index == selectedViewCollection {
                        proto.active = true
                        proto.setNeedsUpdate()
                        proto.triggerUpdate()
                    } else {
                        proto.active = false
                    }
                }
            }
        }
    }
    
    @available(*, unavailable)
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        fatalError("Unavailable")
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Unavailable")
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
                
                experimentViewControllers.append(ExperimentViewController(modules: m))
            }
        }
        
        viewModules = modules
        
        selectedViewCollection = 0
        
        super.init(nibName: nil, bundle: nil)
        
        self.navigationItem.title = experiment.localizedTitle
        
        webServer.delegate = self
        
        defer {
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ExperimentPageViewController.onResignActiveNotification), name: ResignActiveNotification, object: nil)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ExperimentPageViewController.onDidBecomeActiveNotification), name: DidBecomeActiveNotification, object: nil)
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    var webserverWasRunning = false
    dynamic func onResignActiveNotification() {
        stopExperiment()
        if (webServer.running) {
            webserverWasRunning = true
            tearDownWebServer()
        } else {
            webserverWasRunning = false
        }
    }
    
    dynamic func onDidBecomeActiveNotification() {
        if (webserverWasRunning) {
            launchWebServer()
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.barTintColor = kHighlightColor
        self.navigationController?.navigationBar.translucent = false
    }
    
    func updateLayout() {
        var offsetTop : CGFloat = self.topLayoutGuide.length
        let tabBarHeight : CGFloat = 30
        if (experiment.viewDescriptors!.count > 1) {
            offsetTop += tabBarHeight
        }
        var pageViewControlerRect = CGRect(x: 0, y: offsetTop, width: self.view.frame.width, height: self.view.frame.height-offsetTop)
        
        if let label = self.serverLabel {
            let s = label.sizeThatFits(CGSize(width: pageViewControlerRect.width, height: 200))
            pageViewControlerRect = CGRect(origin: pageViewControlerRect.origin, size: CGSize(width: pageViewControlerRect.width, height: pageViewControlerRect.height-s.height))
            
            let labelFrame = CGRect(x: 0, y: self.view.frame.height - s.height, width: pageViewControlerRect.width, height: s.height)
            label.frame = labelFrame
            label.autoresizingMask = [.FlexibleTopMargin, .FlexibleWidth]
        }
        
        self.pageViewControler.view.frame = pageViewControlerRect
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.automaticallyAdjustsScrollViewInsets = false
        self.edgesForExtendedLayout = UIRectEdge.None
        
        let actionItem = UIBarButtonItem(image: generateDots(20.0), landscapeImagePhone: generateDots(15.0), style: .Plain, target: self, action: #selector(action(_:)))
        actionItem.imageInsets = UIEdgeInsets(top: 0.0, left: -25.0, bottom: 0.0, right: 0.0)
        self.navigationItem.rightBarButtonItems = [actionItem, UIBarButtonItem(barButtonSystemItem: .Play, target: self, action: #selector(toggleExperiment))]
        
        //TabBar to switch collections
        let tabBarHeight : CGFloat = 30
        if (experiment.viewDescriptors!.count > 1) {
            var buttons: [String] = []
            for collection in experiment.viewDescriptors! {
                buttons.append(collection.localizedLabel)
            }
            segControl = UISegmentedControl(items: buttons)
            segControl!.addTarget(self, action: #selector(switchToCollection), forControlEvents: .ValueChanged)
            
            segControl!.apportionsSegmentWidthsByContent = true
            
            segControl!.tintColor = kTextColor
            segControl!.backgroundColor = kTextColor
            
            //Generate new background and divider images for the segControl
            let rect = CGRectMake(0, 0, 1, tabBarHeight)
            UIGraphicsBeginImageContext(rect.size)
            let ctx = UIGraphicsGetCurrentContext()
            
            //Background
            CGContextSetFillColorWithColor(ctx!, kLightBackgroundColor.CGColor)
            CGContextFillRect(ctx!, rect)
            let bgImage = UIGraphicsGetImageFromCurrentImageContext()
            
            //Higlighted image, bg with underline
            CGContextSetFillColorWithColor(ctx!, kHighlightColor.CGColor)
            CGContextFillRect(ctx!, CGRectMake(0, tabBarHeight-2, 1, 2))
            let highlightImage = UIGraphicsGetImageFromCurrentImageContext()
            
            UIGraphicsEndImageContext()
            
            segControl!.setBackgroundImage(bgImage, forState: .Normal, barMetrics: .Default)
            segControl!.setBackgroundImage(highlightImage, forState: .Selected, barMetrics: .Default)
            segControl!.setDividerImage(bgImage, forLeftSegmentState: .Normal, rightSegmentState: .Normal, barMetrics: .Default)
            
            let tabBar = UIView()
            tabBar.frame = CGRect(x: 0, y: self.topLayoutGuide.length, width: self.view.frame.width, height: tabBarHeight)
            tabBar.autoresizingMask = .FlexibleWidth
            tabBar.backgroundColor = kLightBackgroundColor
            tabBar.addSubview(segControl!)
            
            self.view.addSubview(tabBar)
           
        }
        
        pageViewControler.delegate = self
        pageViewControler.dataSource = self
        pageViewControler.setViewControllers([experimentViewControllers[0]], direction: .Forward, animated: false, completion: nil)
        pageViewControler.view.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
        
        updateLayout()
        
        self.addChildViewController(pageViewControler)
        self.view.addSubview(pageViewControler.view)
        
        pageViewControler.didMoveToParentViewController(self)
        
        updateSelectedViewCollection()
        
        //Ask to save the experiment locally if it has been loaded from a remote source
        if experiment.source != nil {
            let al = UIAlertController(title: NSLocalizedString("save_locally", comment: ""), message: NSLocalizedString("save_locally_message", comment: ""), preferredStyle: .Alert)
            
            al.addAction(UIAlertAction(title: NSLocalizedString("save_locally_button", comment: ""), style: .Default, handler: { _ in
                self.saveLocally()}))
            al.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .Cancel, handler: nil))
            
            self.navigationController!.presentViewController(al, animated: true, completion: nil)
            
        //Show a hint for the experiment info
        } else if (experiment.localizedCategory != NSLocalizedString("categoryRawSensor", comment: "")) {
            let label = UILabel()
            label.text = NSLocalizedString("experimentinfo_hint", comment: "")
            label.lineBreakMode = .ByWordWrapping
            label.numberOfLines = 0
            label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
            label.textColor = kDarkBackgroundColor
            let maxSize = CGSizeMake(self.view.frame.width*2/3, self.view.frame.height*2/3)
            label.frame.size = label.sizeThatFits(maxSize)
            label.frame.offsetInPlace(dx: 10, dy: 10)
            let paddedFrame = CGRectInset(label.frame, -10, -10)
            let popoverHint = UIViewController()
            popoverHint.view.addSubview(label)
            popoverHint.preferredContentSize = paddedFrame.size
            popoverHint.modalPresentationStyle = UIModalPresentationStyle.Popover
            let pc = popoverHint.popoverPresentationController
            pc?.permittedArrowDirections = .Any
            pc?.barButtonItem = actionItem
            pc?.sourceView = self.view
            pc?.delegate = self
            self.presentViewController(popoverHint, animated: true, completion: nil)
            
            let tapHandler = UITapGestureRecognizer.init(target: self, action: #selector(closeHint))
            tapHandler.delegate = self
            tapHandler.numberOfTapsRequired = 1
            popoverHint.view.userInteractionEnabled = true
            popoverHint.view.addGestureRecognizer(tapHandler)
        }
        
    }
    
    //Force iPad-style popups (for the hint to the menu)
    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController) -> UIModalPresentationStyle {
        return .None
    }
    
    func closeHint(sender: UITapGestureRecognizer? = nil) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        if (self.isMovingFromParentViewController()) {
            for collection in viewModules {
                for module in collection {
                    if let proto = module as? ExperimentViewModuleProtocol {
                        proto.unregisterFromBuffer()
                    }
                }
            }
        
            tearDownWebServer()
        
            experimentStartTimer?.invalidate()
            experimentStartTimer = nil
        
            experimentRunTimer?.invalidate()
            experimentRunTimer = nil
        
            experiment.stop()
            experiment.didBecomeInactive()
        }
    }
    
    func switchToCollection(sender: UISegmentedControl) {
        let direction = selectedViewCollection < sender.selectedSegmentIndex ? UIPageViewControllerNavigationDirection.Forward : UIPageViewControllerNavigationDirection.Reverse
        pageViewControler.setViewControllers([experimentViewControllers[sender.selectedSegmentIndex]], direction: direction, animated: true, completion: nil)
        selectedViewCollection = sender.selectedSegmentIndex
    }
    
    func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
        if selectedViewCollection == 0 {
            return nil
        }
        
        return experimentViewControllers[selectedViewCollection-1]
    }
    
    func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {
        if selectedViewCollection + 1 >= experimentViewControllers.count {
            return nil
        }
        
        return experimentViewControllers[selectedViewCollection+1]
    }
    
    func pageViewController(pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if !completed {
            return
        }
        
        for (index, view) in experimentViewControllers.enumerate() {
            if view == pageViewControler.viewControllers![0] as! ExperimentViewController {
                selectedViewCollection = index
                break
            }
        }
    }
    
    private func launchWebServer() {
        UIApplication.sharedApplication().idleTimerDisabled = true
        if !webServer.start() {
            let hud = JGProgressHUD(style: .Dark)
            hud.interactionType = .BlockTouchesOnHUDView
            hud.indicatorView = JGProgressHUDErrorIndicatorView()
            hud.textLabel.text = "Failed to initialize HTTP server"
            
            hud.showInView(self.view)
            
            hud.dismissAfterDelay(3.0)
        }
        else {
            var url = String(webServer.server!.serverURL)
            //This does not work when using the mobile hotspot, so if we did not get a valid address, we will have to determine it ourselves...
            if url == "nil" {
                print("Fallback to generate URL from IP.")
                var ip: String? = nil
                var interfaceAdresses: UnsafeMutablePointer<ifaddrs> = nil
                if getifaddrs(&interfaceAdresses) == 0 {
                    var iPtr = interfaceAdresses
                    while iPtr != nil {
                        defer {iPtr = iPtr.memory.ifa_next}
                        
                        let interface = iPtr.memory
                        if interface.ifa_addr.memory.sa_family == UInt8(AF_INET) {
                            if let name = String.fromCString(interface.ifa_name) {
                                if name == "bridge100" { //This is the "hotspot interface"
                                    var addr = interface.ifa_addr.memory
                                    var hostname = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0)
                                    getnameinfo(&addr, socklen_t(interface.ifa_addr.memory.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                                    ip = String.fromCString(hostname)
                                }
                            }
                        }
                    }
                }
                if ip != nil {
                    url = "http://\(ip!)/"
                } else {
                    url = "Error: No active network."
                }
            }
            
            self.serverLabel = UILabel()
            self.serverLabel!.lineBreakMode = .ByWordWrapping
            self.serverLabel!.numberOfLines = 0
            self.serverLabel!.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
            self.serverLabel!.textColor = kTextColor
            self.serverLabel!.backgroundColor = kLightBackgroundColor
            self.serverLabel!.text = NSLocalizedString("remoteServerActive", comment: "")+"\n\(url)"
            self.view.addSubview(self.serverLabel!)
            
            updateLayout()
        }
    }
    
    private func tearDownWebServer() {
        webServer.stop()
        if let label = self.serverLabel {
            label.removeFromSuperview()
        }
        self.serverLabel = nil
        updateLayout()
        if (!self.experiment.running) {
            UIApplication.sharedApplication().idleTimerDisabled = false
        }
    }
    
    private func toggleWebServer() {
        if webServer.running {
            tearDownWebServer()
        }
        else {
            let al = UIAlertController(title: NSLocalizedString("remoteServerWarningTitle", comment: ""), message: NSLocalizedString("remoteServerWarning", comment: ""), preferredStyle: .Alert)
            
            al.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .Default, handler: { [unowned self] action in
                self.launchWebServer()
                }))
            al.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .Cancel, handler: nil))
            
            self.navigationController!.presentViewController(al, animated: true, completion: nil)
        }
    }
    
    private func runExportFromActionSheet() {
        let format = exportSelectionView!.selectedFormat()
        
        let HUD = JGProgressHUD(style: .Dark)
        HUD.interactionType = .BlockTouchesOnHUDView
        HUD.textLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        
        HUD.showInView(navigationController!.view)
        
        runExport(format) { error, URL in
            if error != nil {
                HUD.indicatorView = JGProgressHUDErrorIndicatorView()
                HUD.textLabel.text = error!.localizedDescription
                HUD.dismissAfterDelay(3.0)
            }
            else {
                let vc = UIActivityViewController(activityItems: [URL!], applicationActivities: nil)

                vc.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItems![0]

                self.navigationController!.presentViewController(vc, animated: true) {
                    HUD.dismiss()
                }
                
                vc.completionWithItemsHandler = { _ in
                    do { try NSFileManager.defaultManager().removeItemAtURL(URL!) } catch {}
                }
            }
        }
    }
    
    func runExport(format: ExportFileFormat, completion: (NSError?, NSURL?) -> Void) {
        self.experiment.export!.runExport(format) { (errorMessage, fileURL) in
            if let error = errorMessage {
                completion(NSError(domain: NSURLErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: error]), nil)
            }
            else if let URL = fileURL {
                completion(nil, URL)
            }
        }
    }
    
    private func showExport() {
        let alert = UIAlertController(title: NSLocalizedString("export", comment: ""), message: NSLocalizedString("pick_exportFormat", comment: ""), preferredStyle: .Alert)
        
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
            if (!self.timerEnabled) {
                let label = UILabel()
                label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
                label.textColor = kTextColor
                label.text = "\(alert.textFields!.first!.text ?? "0")s"
                label.sizeToFit()
            
                var items = self.navigationItem.rightBarButtonItems!
                items.append(UIBarButtonItem(customView: label))
                self.navigationItem.rightBarButtonItems = items
            }
            
            self.timerEnabled = true
            self.timerDelayString = alert.textFields!.first!.text
            self.timerDurationString = alert.textFields!.last!.text
            }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("disableTimedRun", comment: ""), style: .Cancel, handler: { [unowned self, unowned alert] action in
            if (self.timerEnabled) {
                var items = self.navigationItem.rightBarButtonItems!
                items.removeLast()
                self.navigationItem.rightBarButtonItems = items
            }
            
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
            
            let links: [String:String] = self.experiment.localizedLinks
            for (key, value) in links {
                al.addAction(UIAlertAction(title: NSLocalizedString(key, comment: ""), style: .Default, handler: { _ in
                    UIApplication.sharedApplication().openURL(NSURL(string: value)!)
                }))
            }
            
            al.addAction(UIAlertAction(title: NSLocalizedString("close", comment: ""), style: .Cancel, handler: nil))
            
            self.navigationController!.presentViewController(al, animated: true, completion: nil)
            }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("share", comment: ""), style: .Default, handler: { [unowned self] action in
            let w = UIApplication.sharedApplication().keyWindow!
            let s = UIScreen.mainScreen().scale
            UIGraphicsBeginImageContextWithOptions(w.frame.size, false, s)
            w.drawViewHierarchyInRect(w.frame, afterScreenUpdates: false)
            let img = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            let png = UIImagePNGRepresentation(img!)!
            
            let HUD = JGProgressHUD(style: .Dark)
            HUD.interactionType = .BlockTouchesOnHUDView
            HUD.textLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)

            HUD.showInView(self.navigationController!.view)

            let dateFormatter = NSDateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
            let tmpFile = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent("phyphox \(dateFormatter.stringFromDate(NSDate())).png")
            
            do { try NSFileManager.defaultManager().removeItemAtPath(tmpFile) } catch {}
            do { try png.writeToFile(tmpFile, options: .DataWritingFileProtectionNone) } catch {}
            let tmpFileURL = NSURL(fileURLWithPath: tmpFile)
            
            let vc = UIActivityViewController(activityItems: [tmpFileURL], applicationActivities: nil)
            
            vc.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItems![0]
            
            self.navigationController!.presentViewController(vc, animated: true) {
                HUD.dismiss()
            }
            
            vc.completionWithItemsHandler = { _ in
                do { try NSFileManager.defaultManager().removeItemAtPath(tmpFile) } catch {}
            }
            
            }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("clear_data", comment: ""), style: .Destructive, handler: { [unowned self] action in
            self.clearData()
            }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .Cancel, handler: nil))
        
        if experiment.source != nil {
            alert.addAction(UIAlertAction(title: NSLocalizedString("save_locally", comment: ""), style: .Default, handler: { [unowned self] action in
                self.saveLocally()
            }))
        }
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = item
        }
        
        self.navigationController!.presentViewController(alert, animated: true, completion: nil)
    }
    
    func saveLocally() {
        var i = 1
        let title = self.experiment.source!.lastPathComponent
        var t = title
        
        var path: String
        
        let directory = customExperimentsDirectory
        
        do {
            if !NSFileManager.defaultManager().fileExistsAtPath(directory) {
                try NSFileManager.defaultManager().createDirectoryAtPath(directory, withIntermediateDirectories: false, attributes: nil)
            }
        } catch {
            return
        }
        
        repeat {
            path = (directory as NSString).stringByAppendingPathComponent("\(t).phyphox")
            
            t = "\(title)-\(i)"
            i += 1
            
        } while NSFileManager.defaultManager().fileExistsAtPath(path)
        
        self.experiment.sourceData!.writeToFile(path, atomically: true)
        self.experiment.source = nil
        
        ExperimentManager.sharedInstance().loadCustomExperiments()
        
        let confirmation = UIAlertController(title: NSLocalizedString("save_locally", comment: ""), message: NSLocalizedString("save_locally_done", comment: ""), preferredStyle: .Alert)
        
        confirmation.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .Default, handler: nil))
        self.navigationController!.presentViewController(confirmation, animated: true, completion: nil)
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
        
        label.text = "\(i)s"
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
                
                label.text = "\(t)s"
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
            UIApplication.sharedApplication().idleTimerDisabled = true
            
            if experimentStartTimer != nil {
                experimentStartTimer!.invalidate()
                experimentStartTimer = nil
                
                return
            }
            
            if timerEnabled {
                let d = Double(timerDelayString ?? "0") ?? 0.0
                let i = Int(d)
                
                var items = navigationItem.rightBarButtonItems!
                
                let label = items.last!.customView! as! UILabel
                
                label.text = "\(i)s"
                label.sizeToFit()
                
                items.removeLast()
                items.append(UIBarButtonItem(customView: label))
                
                navigationItem.rightBarButtonItems = items
                
                func updateT() {
                    if self.experimentStartTimer != nil {
                        let t = Int(round(self.experimentStartTimer!.fireDate.timeIntervalSinceNow))
                        
                        after(1.0, closure: {
                            updateT()
                        })
                        
                        label.text = "\(t)s"
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
            if (!self.webServer.running) {
                UIApplication.sharedApplication().idleTimerDisabled = false
            }
            
            var items = navigationItem.rightBarButtonItems!
            
            if experimentRunTimer != nil {
                experimentRunTimer!.invalidate()
                experimentRunTimer = nil
                
                let label = items.last!.customView! as! UILabel
                
                label.text = "\(self.timerDelayString ?? "0")s"
                label.sizeToFit()
                
                items.removeLast()
                items.append(UIBarButtonItem(customView: label))

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
        
        self.webServer.forceFullUpdate = true //The next time, the webinterface requests buffers, we need to send a full update, so the now empty buffers can be recognized
        
        for section in self.viewModules {
            for view in section {
                if let graphView = view as? ExperimentGraphView {
                    graphView.clearAllDataSets()
                }
            }
        }
    }
}
