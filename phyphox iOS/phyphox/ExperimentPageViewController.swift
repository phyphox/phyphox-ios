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
    var tabBar: UIScrollView? = nil
    let tabBarHeight : CGFloat = 30
    
    let pageViewControler: UIPageViewController = UIPageViewController(transitionStyle: UIPageViewControllerTransitionStyle.scroll, navigationOrientation: UIPageViewControllerNavigationOrientation.horizontal, options: nil)
    
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
    
    private var experimentStartTimer: Timer?
    private var experimentRunTimer: Timer?
    
    private var exportSelectionView: ExperimentExportSetSelectionView?
    
    var selectedViewCollection: Int {
        didSet {
            if selectedViewCollection != oldValue {
                updateSelectedViewCollection()
            }
        }
    }
    
    func updateTabScrollPosition(_ target: Int) {
        if segControl == nil {
            return
        }
        let w = segControl!.frame.width/CGFloat(experimentViewControllers.count)
        let targetFrame = CGRect(x: (CGFloat(target)-0.5)*w, y: 0, width: 2*w, height: tabBarHeight)
        
        tabBar?.scrollRectToVisible(targetFrame, animated: true)
    }
    
    func updateSelectedViewCollection() {
        segControl?.selectedSegmentIndex = selectedViewCollection
        updateTabScrollPosition(selectedViewCollection)
        
        for (index, collection) in viewModules.enumerated() {
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
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
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
            NotificationCenter.default.addObserver(self, selector: #selector(ExperimentPageViewController.onResignActiveNotification), name: NSNotification.Name(rawValue: ResignActiveNotification), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(ExperimentPageViewController.onDidBecomeActiveNotification), name: NSNotification.Name(rawValue: DidBecomeActiveNotification), object: nil)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    var webserverWasRunning = false
    @objc dynamic func onResignActiveNotification() {
        stopExperiment()
        if (webServer.running) {
            webserverWasRunning = true
            tearDownWebServer()
        } else {
            webserverWasRunning = false
        }
    }
    
    @objc dynamic func onDidBecomeActiveNotification() {
        if (webserverWasRunning) {
            launchWebServer()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.barTintColor = kHighlightColor
        self.navigationController?.navigationBar.isTranslucent = false
    }
    
    func updateLayout() {
        var offsetTop : CGFloat = self.topLayoutGuide.length
        if (experiment.viewDescriptors!.count > 1) {
            offsetTop += tabBarHeight
        }
        var pageViewControlerRect = CGRect(x: 0, y: offsetTop, width: self.view.frame.width, height: self.view.frame.height-offsetTop)
        
        if let label = self.serverLabel {
            let s = label.sizeThatFits(CGSize(width: pageViewControlerRect.width, height: 200))
            pageViewControlerRect = CGRect(origin: pageViewControlerRect.origin, size: CGSize(width: pageViewControlerRect.width, height: pageViewControlerRect.height-s.height))
            
            let labelFrame = CGRect(x: 0, y: self.view.frame.height - s.height, width: pageViewControlerRect.width, height: s.height)
            label.frame = labelFrame
            label.autoresizingMask = [.flexibleTopMargin, .flexibleWidth]
        }
        
        self.pageViewControler.view.frame = pageViewControlerRect
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.automaticallyAdjustsScrollViewInsets = false
        self.edgesForExtendedLayout = UIRectEdge()
        
        let actionItem = UIBarButtonItem(image: generateDots(20.0), landscapeImagePhone: generateDots(15.0), style: .plain, target: self, action: #selector(action(_:)))
        actionItem.accessibilityLabel = NSLocalizedString("actions", comment: "")
        let deleteItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(clearDataDialog))
        deleteItem.accessibilityLabel = NSLocalizedString("clear_data", comment: "")
        let playItem = UIBarButtonItem(barButtonSystemItem: .play, target: self, action: #selector(toggleExperiment))
        self.navigationItem.rightBarButtonItems = [
            actionItem,
            deleteItem,
            playItem
        ]
        
        //TabBar to switch collections
        if (experiment.viewDescriptors!.count > 1) {
            var buttons: [String] = []
            for collection in experiment.viewDescriptors! {
                buttons.append(collection.localizedLabel)
            }
            segControl = UISegmentedControl(items: buttons)
            segControl!.addTarget(self, action: #selector(switchToCollection), for: .valueChanged)
            
            segControl!.apportionsSegmentWidthsByContent = true
            
            segControl!.tintColor = kTextColor
            segControl!.backgroundColor = kTextColor
            
            //Generate new background and divider images for the segControl
            let rect = CGRect(x: 0, y: 0, width: 1, height: tabBarHeight)
            UIGraphicsBeginImageContext(rect.size)
            let ctx = UIGraphicsGetCurrentContext()
            
            //Background
            ctx!.setFillColor(kLightBackgroundColor.cgColor)
            ctx!.fill(rect)
            let bgImage = UIGraphicsGetImageFromCurrentImageContext()
            
            //Higlighted image, bg with underline
            ctx!.setFillColor(kHighlightColor.cgColor)
            ctx!.fill(CGRect(x: 0, y: tabBarHeight-2, width: 1, height: 2))
            let highlightImage = UIGraphicsGetImageFromCurrentImageContext()
            
            UIGraphicsEndImageContext()
            
            segControl!.setBackgroundImage(bgImage, for: UIControlState(), barMetrics: .default)
            segControl!.setBackgroundImage(highlightImage, for: .selected, barMetrics: .default)
            segControl!.setDividerImage(bgImage, forLeftSegmentState: UIControlState(), rightSegmentState: UIControlState(), barMetrics: .default)
            segControl!.sizeToFit()
            
            tabBar = UIScrollView()
            tabBar!.frame = CGRect(x: 0, y: self.topLayoutGuide.length, width: self.view.frame.width, height: tabBarHeight)
            tabBar!.contentSize = segControl!.frame.size
            tabBar!.showsHorizontalScrollIndicator = false
            tabBar!.autoresizingMask = .flexibleWidth
            tabBar!.backgroundColor = kLightBackgroundColor
            tabBar!.addSubview(segControl!)
            
            self.view.addSubview(tabBar!)
           
        }
        
        pageViewControler.delegate = self
        pageViewControler.dataSource = self
        pageViewControler.setViewControllers([experimentViewControllers[0]], direction: .forward, animated: false, completion: nil)
        pageViewControler.view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        updateLayout()
        
        self.addChildViewController(pageViewControler)
        self.view.addSubview(pageViewControler.view)
        
        pageViewControler.didMove(toParentViewController: self)
        
        updateSelectedViewCollection()
        
        //Ask to save the experiment locally if it has been loaded from a remote source
        if experiment.source != nil {
            let al = UIAlertController(title: NSLocalizedString("save_locally", comment: ""), message: NSLocalizedString("save_locally_message", comment: ""), preferredStyle: .alert)
            
            al.addAction(UIAlertAction(title: NSLocalizedString("save_locally_button", comment: ""), style: .default, handler: { _ in
                self.saveLocally()}))
            al.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
            
            self.navigationController!.present(al, animated: true, completion: nil)
            
        //Show a hint for the experiment info
        } else if (experiment.localizedCategory != NSLocalizedString("categoryRawSensor", comment: "")) {
            let label = UILabel()
            label.text = NSLocalizedString("experimentinfo_hint", comment: "")
            label.lineBreakMode = .byWordWrapping
            label.numberOfLines = 0
            label.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
            label.textColor = kDarkBackgroundColor
            let maxSize = CGSize(width: self.view.frame.width*2/3, height: self.view.frame.height*2/3)
            label.frame.size = label.sizeThatFits(maxSize)
            label.frame = label.frame.offsetBy(dx: 10, dy: 10)
            let paddedFrame = label.frame.insetBy(dx: -10, dy: -10)
            let popoverHint = UIViewController()
            popoverHint.view.addSubview(label)
            popoverHint.preferredContentSize = paddedFrame.size
            popoverHint.modalPresentationStyle = UIModalPresentationStyle.popover
            let pc = popoverHint.popoverPresentationController
            pc?.permittedArrowDirections = .any
            pc?.barButtonItem = actionItem
            pc?.sourceView = self.view
            pc?.delegate = self
            self.present(popoverHint, animated: true, completion: nil)
            
            let tapHandler = UITapGestureRecognizer.init(target: self, action: #selector(closeHint))
            tapHandler.delegate = self
            tapHandler.numberOfTapsRequired = 1
            popoverHint.view.isUserInteractionEnabled = true
            popoverHint.view.addGestureRecognizer(tapHandler)
        }
        
    }
    
    //Force iPad-style popups (for the hint to the menu)
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    @objc func closeHint(_ sender: UITapGestureRecognizer? = nil) {
        self.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if (self.isMovingFromParentViewController) {
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
    
    @objc func switchToCollection(_ sender: UISegmentedControl) {
        let direction = selectedViewCollection < sender.selectedSegmentIndex ? UIPageViewControllerNavigationDirection.forward : UIPageViewControllerNavigationDirection.reverse
        pageViewControler.setViewControllers([experimentViewControllers[sender.selectedSegmentIndex]], direction: direction, animated: true, completion: nil)
        selectedViewCollection = sender.selectedSegmentIndex
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if selectedViewCollection == 0 {
            return nil
        }
        
        return experimentViewControllers[selectedViewCollection-1]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if selectedViewCollection + 1 >= experimentViewControllers.count {
            return nil
        }
        
        return experimentViewControllers[selectedViewCollection+1]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        for (index, view) in experimentViewControllers.enumerated() {
            if view == pendingViewControllers[0] as! ExperimentViewController {
                updateTabScrollPosition(index)
            }
        }
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if !completed {
            return
        }
        
        for (index, view) in experimentViewControllers.enumerated() {
            if view == pageViewControler.viewControllers![0] as! ExperimentViewController {
                selectedViewCollection = index
                break
            }
        }
    }
    
    private func launchWebServer() {
        UIApplication.shared.isIdleTimerDisabled = true
        if !webServer.start() {
            let hud = JGProgressHUD(style: .dark)
            hud?.interactionType = .blockTouchesOnHUDView
            hud?.indicatorView = JGProgressHUDErrorIndicatorView()
            hud?.textLabel.text = "Failed to initialize HTTP server"
            
            hud?.show(in: self.view)
            
            hud?.dismiss(afterDelay: 3.0)
        }
        else {
            var url = webServer.server!.serverURL?.absoluteString
            //This does not work when using the mobile hotspot, so if we did not get a valid address, we will have to determine it ourselves...
            if url == nil || url == "nil" {
                print("Fallback to generate URL from IP.")
                var ip: String? = nil
                var interfaceAdresses: UnsafeMutablePointer<ifaddrs>? = nil
                if getifaddrs(&interfaceAdresses) == 0 {
                    var iPtr = interfaceAdresses
                    while iPtr != nil {
                        defer {iPtr = iPtr?.pointee.ifa_next}
                        
                        let interface = iPtr?.pointee
                        if interface?.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                            if let name = String(validatingUTF8: (interface?.ifa_name)!) {
                                if name == "bridge100" { //This is the "hotspot interface"
                                    var addr = interface?.ifa_addr.pointee
                                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                                    getnameinfo(&addr!, socklen_t((interface?.ifa_addr.pointee.sa_len)!), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                                    ip = String(cString: hostname)
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
            self.serverLabel!.lineBreakMode = .byWordWrapping
            self.serverLabel!.numberOfLines = 0
            self.serverLabel!.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
            self.serverLabel!.textColor = kTextColor
            self.serverLabel!.backgroundColor = kLightBackgroundColor
            self.serverLabel!.text = NSLocalizedString("remoteServerActive", comment: "")+"\n\(url!)"
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
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    private func toggleWebServer() {
        if webServer.running {
            tearDownWebServer()
        }
        else {
            let al = UIAlertController(title: NSLocalizedString("remoteServerWarningTitle", comment: ""), message: NSLocalizedString("remoteServerWarning", comment: ""), preferredStyle: .alert)
            
            al.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: { [unowned self] action in
                self.launchWebServer()
                }))
            al.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
            
            self.navigationController!.present(al, animated: true, completion: nil)
        }
    }
    
    private func runExportFromActionSheet() {
        let format = exportSelectionView!.selectedFormat()
        
        let HUD = JGProgressHUD(style: .dark)
        HUD?.interactionType = .blockTouchesOnHUDView
        HUD?.textLabel.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)
        
        HUD?.show(in: navigationController!.view)
        
        runExport(format: format) { error, URL in
            if error != nil {
                HUD?.indicatorView = JGProgressHUDErrorIndicatorView()
                HUD?.textLabel.text = error!.localizedDescription
                HUD?.dismiss(afterDelay: 3.0)
            }
            else {
                let vc = UIActivityViewController(activityItems: [URL!], applicationActivities: nil)

                vc.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItems![0]

                self.navigationController!.present(vc, animated: true) {
                    HUD?.dismiss()
                }
                
                vc.completionWithItemsHandler = { _, _, _, _ in
                    do { try FileManager.default.removeItem(at: URL!) } catch {}
                }
            }
        }
    }
    
    func runExport(format: ExportFileFormat, completion: @escaping (NSError?, URL?) -> Void) {
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
        let alert = UIAlertController(title: NSLocalizedString("export", comment: ""), message: NSLocalizedString("pick_exportFormat", comment: ""), preferredStyle: .alert)
        
        let exportAction = UIAlertAction(title: NSLocalizedString("export", comment: ""), style: .default, handler: { [unowned self] action in
            self.runExportFromActionSheet()
            })
        
        if exportSelectionView == nil {
            exportSelectionView = ExperimentExportSetSelectionView(export: experiment.export!, translation: experiment.translation) { [unowned exportAction] available in
                exportAction.isEnabled = available
            }
        }
        
        alert.addAction(exportAction)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
        
        alert.__pt__setAccessoryView(exportSelectionView!)
        
        self.navigationController!.present(alert, animated: true, completion: nil)
    }
    
    private func showSaveState() {
        self.stopExperiment()
        
        let alert = UIAlertController(title: NSLocalizedString("save_state", comment: ""), message: NSLocalizedString("save_state_message", comment: ""), preferredStyle: .alert)
        
        alert.addTextField(configurationHandler: { (textField) in
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            
            let fileNameDefault = NSLocalizedString("save_state_default_title", comment: "")
            textField.text = "\(fileNameDefault) \(dateFormatter.string(from: Date()))"
        })
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("save_state_save", comment: ""), style: .default, handler: { [unowned self] action in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
            
            let fileNameDefault = NSLocalizedString("save_state_default_title", comment: "")
            let filename = "\(fileNameDefault) \(dateFormatter.string(from: Date())).phyphox"
            let target = (customExperimentsDirectory as NSString).appendingPathComponent(filename)
            
            let HUD = JGProgressHUD(style: .dark)
            HUD?.interactionType = .blockTouchesOnHUDView
            HUD?.textLabel.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)
            
            HUD?.show(in: self.navigationController!.view)
            
            
            do {
                if !FileManager.default.fileExists(atPath: customExperimentsDirectory) {
                    try FileManager.default.createDirectory(atPath: customExperimentsDirectory, withIntermediateDirectories: false, attributes: nil)
                }
            } catch {
                return
            }
            
            StateSerializer.writeStateFile(customTitle: alert.textFields![0].text!, target: target, experiment: self.experiment, callback: {(error, file) in
                if (error != nil) {
                    self.showError(message: error!)
                    return
                }
                
                HUD?.dismiss()
                
                ExperimentManager.sharedInstance().loadCustomExperiments()
                
                let confirmation = UIAlertController(title: NSLocalizedString("save_state", comment: ""), message: NSLocalizedString("save_state_success", comment: ""), preferredStyle: .alert)
                
                confirmation.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
                self.navigationController!.present(confirmation, animated: true, completion: nil)
            })
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("save_state_share", comment: ""), style: .default, handler: { [unowned self] action in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
            
            let fileNameDefault = NSLocalizedString("save_state_default_title", comment: "")
            let tmpFile = (NSTemporaryDirectory() as NSString).appendingPathComponent("\(fileNameDefault) \(dateFormatter.string(from: Date())).phyphox")
            
            let HUD = JGProgressHUD(style: .dark)
            HUD?.interactionType = .blockTouchesOnHUDView
            HUD?.textLabel.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)
            
            HUD?.show(in: self.navigationController!.view)
            
            StateSerializer.writeStateFile(customTitle: alert.textFields![0].text!, target: tmpFile, experiment: self.experiment, callback: {(error, file) in
                if (error != nil) {
                    self.showError(message: error!)
                    return
                }
                
                let vc = UIActivityViewController(activityItems: [file!], applicationActivities: nil)
                
                vc.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItems![0]
                
                self.navigationController!.present(vc, animated: true) {
                    HUD?.dismiss()
                }

                vc.completionWithItemsHandler = { _, _, _, _ in
                    do { try FileManager.default.removeItem(atPath: tmpFile) } catch {}
                }
            })
        }))
            
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
        
        self.navigationController!.present(alert, animated: true, completion: nil)
    }
    
    private func showTimerOptions() {
        let alert = UIAlertController(title: NSLocalizedString("timedRunDialogTitle", comment: ""), message: nil, preferredStyle: .alert)
        
        alert.addTextField { [unowned self] textField in
            textField.keyboardType = .decimalPad
            textField.placeholder = NSLocalizedString("timedRunStartDelay", comment: "")
            
            textField.text = self.timerDelayString
        }
        
        alert.addTextField { [unowned self] textField in
            textField.keyboardType = .decimalPad
            textField.placeholder = NSLocalizedString("timedRunStopDelay", comment: "")
            
            textField.text = self.timerDurationString
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("enableTimedRun", comment: ""), style: .default, handler: { [unowned self, unowned alert] action in
            if (!self.timerEnabled) {
                let label = UILabel()
                label.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)
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
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("disableTimedRun", comment: ""), style: .cancel, handler: { [unowned self, unowned alert] action in
            if (self.timerEnabled) {
                var items = self.navigationItem.rightBarButtonItems!
                items.removeLast()
                self.navigationItem.rightBarButtonItems = items
            }
            
            self.timerEnabled = false
            self.timerDelayString = alert.textFields!.first!.text
            self.timerDurationString = alert.textFields!.last!.text
            }))
        
        self.navigationController!.present(alert, animated: true, completion: nil)
    }
    
    @objc func action(_ item: UIBarButtonItem) {
        let alert = UIAlertController(title: NSLocalizedString("actions", comment: ""), message: nil, preferredStyle: .actionSheet)
        
        if experiment.export != nil {
            alert.addAction(UIAlertAction(title: NSLocalizedString("export", comment: ""), style: .default, handler: { [unowned self] action in
                self.showExport()
                }))
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("timedRun", comment: ""), style: .default, handler: { [unowned self] action in
            self.showTimerOptions()
            }))
        
        alert.addAction(UIAlertAction(title: (webServer.running ? NSLocalizedString("disableRemoteServer", comment: "") : NSLocalizedString("enableRemoteServer", comment: "")), style: .default, handler: { [unowned self] action in
            self.toggleWebServer()
            }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("show_description", comment: ""), style: .default, handler: { [unowned self] action in
            let al = UIAlertController(title: self.experiment.localizedTitle, message: self.experiment.localizedDescription, preferredStyle: .alert)
            
            let links: [String:String] = self.experiment.localizedLinks
            for (key, value) in links {
                al.addAction(UIAlertAction(title: NSLocalizedString(key, comment: ""), style: .default, handler: { _ in
                    UIApplication.shared.openURL(URL(string: value)!)
                }))
            }
            
            al.addAction(UIAlertAction(title: NSLocalizedString("close", comment: ""), style: .cancel, handler: nil))
            
            self.navigationController!.present(al, animated: true, completion: nil)
            }))
        
        let links: [String:String] = self.experiment.localizedHighlightedLinks
        for (key, value) in links {
            alert.addAction(UIAlertAction(title: NSLocalizedString(key, comment: ""), style: .default, handler: { _ in
                UIApplication.shared.openURL(URL(string: value)!)
            }))
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("share", comment: ""), style: .default, handler: { [unowned self] action in
            let w = UIApplication.shared.keyWindow!
            let s = UIScreen.main.scale
            UIGraphicsBeginImageContextWithOptions(w.frame.size, false, s)
            w.drawHierarchy(in: w.frame, afterScreenUpdates: false)
            let img = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            let png = UIImagePNGRepresentation(img!)!
            
            let HUD = JGProgressHUD(style: .dark)
            HUD?.interactionType = .blockTouchesOnHUDView
            HUD?.textLabel.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)

            HUD?.show(in: self.navigationController!.view)

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
            let tmpFile = (NSTemporaryDirectory() as NSString).appendingPathComponent("phyphox \(dateFormatter.string(from: Date())).png")
            
            do { try FileManager.default.removeItem(atPath: tmpFile) } catch {}
            do { try png.write(to: URL(fileURLWithPath: tmpFile), options: .noFileProtection) } catch {}
            let tmpFileURL = URL(fileURLWithPath: tmpFile)
            
            let vc = UIActivityViewController(activityItems: [tmpFileURL], applicationActivities: nil)
            
            vc.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItems![0]
            
            self.navigationController!.present(vc, animated: true) {
                HUD?.dismiss()
            }
            
            vc.completionWithItemsHandler = { _, _, _, _ in
                do { try FileManager.default.removeItem(atPath: tmpFile) } catch {}
            }
            
            }))
        
        var magnetometer: ExperimentSensorInput? = nil
        if (experiment.sensorInputs != nil) {
            for sensor in experiment.sensorInputs! {
                if (sensor.sensorType == SensorType.magneticField) {
                    magnetometer = sensor
                }
            }
        }
        if (magnetometer != nil) {
            if magnetometer!.calibrated {
                alert.addAction(UIAlertAction(title: NSLocalizedString("switch_to_raw_magnetometer", comment: ""), style: .default, handler: { [unowned self] action in
                    self.stopExperiment()
                    magnetometer?.calibrated = false
                    }))
            } else {
                alert.addAction(UIAlertAction(title: NSLocalizedString("switch_to_calibrated_magnetometer", comment: ""), style: .default, handler: { [unowned self] action in
                    self.stopExperiment()
                    magnetometer?.calibrated = true
                    }))
            }
            
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
        
        if experiment.source != nil {
            alert.addAction(UIAlertAction(title: NSLocalizedString("save_locally", comment: ""), style: .default, handler: { [unowned self] action in
                self.saveLocally()
            }))
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("save_state", comment: ""), style: .default, handler: { [unowned self] action in
            self.showSaveState()
        }))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = item
        }
        
        self.navigationController!.present(alert, animated: true, completion: nil)
    }
    
    func saveLocally() {
        var i = 1
        let title = self.experiment.source!.lastPathComponent
        var t = title
        
        var path: String
        
        let directory = customExperimentsDirectory
        
        do {
            if !FileManager.default.fileExists(atPath: directory) {
                try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: false, attributes: nil)
            }
        } catch {
            return
        }
        
        repeat {
            path = (directory as NSString).appendingPathComponent("\(t).phyphox")
            
            t = "\(title)-\(i)"
            i += 1
            
        } while FileManager.default.fileExists(atPath: path)
        
        try? self.experiment.sourceData!.write(to: URL(fileURLWithPath: path), options: [.atomic])
        self.experiment.source = nil
        
        ExperimentManager.sharedInstance().loadCustomExperiments()
        
        let confirmation = UIAlertController(title: NSLocalizedString("save_locally", comment: ""), message: NSLocalizedString("save_locally_done", comment: ""), preferredStyle: .alert)
        
        confirmation.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
        self.navigationController!.present(confirmation, animated: true, completion: nil)
    }

    @objc func stopTimerFired() {
        stopExperiment()
    }

    @objc func startTimerFired() {
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
        
        experimentRunTimer = Timer.scheduledTimer(timeInterval: d, target: self, selector: #selector(stopTimerFired), userInfo: nil, repeats: false)
    }
    
    func startExperiment() {
        if !experiment.running {
            UIApplication.shared.isIdleTimerDisabled = true
            
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
                
                experimentStartTimer = Timer.scheduledTimer(timeInterval: d, target: self, selector: #selector(startTimerFired), userInfo: nil, repeats: false)
            }
            else {
                actuallyStartExperiment()
            }
        }
    }
    
    func showError(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default))
        present(alert, animated: true)
    }
    
    func actuallyStartExperiment() {
        do {
            try experiment.start()
        } catch AudioEngine.AudioEngineError.RateMissmatch {
            showError(message: NSLocalizedString("AudioRateMissmatch", comment: ""))
            experiment.stop()
            return
        } catch {
            showError(message: "Could not start experiment \(error).")
            experiment.stop()
            return
        }
        
        var items = navigationItem.rightBarButtonItems!
        
        items[2] = UIBarButtonItem(barButtonSystemItem: .pause, target: self, action: #selector(toggleExperiment))
        
        navigationItem.rightBarButtonItems = items
    }
    
    func stopExperiment() {
        if experiment.running {
            if (!self.webServer.running) {
                UIApplication.shared.isIdleTimerDisabled = false
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
            
            items[2] = UIBarButtonItem(barButtonSystemItem: .play, target: self, action: #selector(toggleExperiment))
            
            navigationItem.rightBarButtonItems = items
        }
    }
    
    @objc func toggleExperiment() {
        if experiment.running {
            stopExperiment()
        }
        else {
            startExperiment()
        }
    }
    
    @objc func clearDataDialog() {
        let al = UIAlertController(title: NSLocalizedString("clear_data", comment: ""), message: NSLocalizedString("clear_data_question", comment: ""), preferredStyle: .alert)
        
        al.addAction(UIAlertAction(title: NSLocalizedString("clear", comment: ""), style: .default, handler: { [unowned self] action in
            self.clearData()
        }))
        al.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
        
        self.navigationController!.present(al, animated: true, completion: nil)
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
