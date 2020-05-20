//
//  ExperimentPageViewController.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 30.05.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation
import GCDWebServers

protocol ExportDelegate {
    func showExport(_ export: ExperimentExport, singleSet: Bool)
}

protocol StopExperimentDelegate {
    func stopExperiment()
}

final class ExperimentPageViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIPopoverPresentationControllerDelegate, ExperimentWebServerDelegate, ExportDelegate, StopExperimentDelegate, BluetoothScanDialogDismissedDelegate, NetworkScanDialogDismissedDelegate, NetworkConnectionDataPolicyInfoDelegate {
    
    var actionItem: UIBarButtonItem?
    var playItem: UIBarButtonItem?
    
    var segControl: UISegmentedControl? = nil
    var tabBar: UIScrollView? = nil
    let tabBarHeight : CGFloat = 30
    
    let pageViewControler: UIPageViewController = UIPageViewController(transitionStyle: UIPageViewControllerTransitionStyle.scroll, navigationOrientation: UIPageViewControllerNavigationOrientation.horizontal, options: nil)
    
    var serverLabel: UILabel? = nil
    var serverLabelBackground: UIView? = nil
    
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
    
    private var timerDelay: Double
    private var timerDuration: Double
    private var timerEnabled = false
    
    private var experimentStartTimer: Timer?
    private var experimentRunTimer: Timer?
    
    private var exportSelectionView: ExperimentExportSetSelectionView?
    
    var selectedViewCollection: Int {
        didSet {
            if selectedViewCollection != oldValue {
                experimentViewControllers[oldValue].active = false
                experimentViewControllers[selectedViewCollection].active = true
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
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateLayout()
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
        
        self.timerEnabled = experiment.analysis?.timedRun ?? false
        self.timerDelay = experiment.analysis?.timedRunStartDelay ?? 3.0
        self.timerDuration = experiment.analysis?.timedRunStopDelay ?? 10.0
        
        var modules: [[UIView]] = []
        
        if let descriptors = experiment.viewDescriptors {
            for collection in descriptors {
                let m = ExperimentViewModuleFactory.createViews(collection)
                
                modules.append(m)
                
                experimentViewControllers.append(ExperimentViewController(modules: m))
            }
        }
        
        viewModules = modules
        
        selectedViewCollection = 0

        super.init(nibName: nil, bundle: nil)

        experimentViewControllers.first?.active = true

        for module in viewModules.flatMap({ $0 }) {
            if let button = module as? ExperimentButtonView {
                button.buttonTappedCallback = { [weak self, weak button] in
                    guard let button = button else { return }
                    self?.buttonPressed(viewDescriptor: button.descriptor, buttonViewTriggerCallback: button)
                }
            }
            if let exportingViewModule = module as? ExportingViewModule {
                exportingViewModule.exportDelegate = self
            }
        }

        self.navigationItem.title = experiment.displayTitle
        
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
    @objc func onResignActiveNotification() {
        stopExperiment()
        if (webServer.running) {
            webserverWasRunning = true
            tearDownWebServer()
        } else {
            webserverWasRunning = false
        }
    }
    
    @objc func onDidBecomeActiveNotification() {
        if (webserverWasRunning) {
            launchWebServer()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if isMovingToParentViewController {
            experiment.willBecomeActive {
                self.navigationController?.popToRootViewController(animated: true)
            }
        }

        self.navigationController?.navigationBar.barTintColor = kHighlightColor
        self.navigationController?.navigationBar.isTranslucent = false
    }
    
    func updateLayout() {
        var offsetTop : CGFloat = self.topLayoutGuide.length
        if (experiment.viewDescriptors!.count > 1) {
            offsetTop += tabBarHeight
        }
        let offsetBottom: CGFloat = self.bottomLayoutGuide.length
        let offsetFrame: CGRect
        if #available(iOS 11, *) {
            offsetFrame = self.view.safeAreaLayoutGuide.layoutFrame
        } else {
            offsetFrame = self.view.frame
        }
        
        var pageViewControlerRect = CGRect(x: 0, y: offsetTop, width: self.view.frame.width, height: self.view.frame.height-offsetTop)
        
        if let label = self.serverLabel, let labelBackground = self.serverLabelBackground {
            let s = label.sizeThatFits(CGSize(width: offsetFrame.width, height: 300))
            pageViewControlerRect = CGRect(origin: pageViewControlerRect.origin, size: CGSize(width: pageViewControlerRect.width, height: pageViewControlerRect.height-s.height-offsetBottom))
            
            let labelBackgroundFrame = CGRect(x: 0, y: self.view.frame.height - s.height - offsetBottom, width: pageViewControlerRect.width, height: s.height + offsetBottom)
            let labelFrame = CGRect(x: offsetFrame.minX, y: self.view.frame.height - s.height - offsetBottom, width: offsetFrame.width, height: s.height)
            label.frame = labelFrame
            labelBackground.frame = labelBackgroundFrame
            label.autoresizingMask = [.flexibleTopMargin, .flexibleWidth]
            labelBackground.autoresizingMask = [.flexibleTopMargin, .flexibleWidth]
        }
        
        self.pageViewControler.view.frame = pageViewControlerRect
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.automaticallyAdjustsScrollViewInsets = false
        self.edgesForExtendedLayout = UIRectEdge()
        
        actionItem = UIBarButtonItem(image: generateDots(20.0), landscapeImagePhone: generateDots(15.0), style: .plain, target: self, action: #selector(action(_:)))
        actionItem?.accessibilityLabel = localize("actions")
        let deleteItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(clearDataDialog))
        deleteItem.accessibilityLabel = localize("clear_data")
        playItem = UIBarButtonItem(barButtonSystemItem: .play, target: self, action: #selector(toggleExperiment))
        self.navigationItem.rightBarButtonItems = [
            actionItem!,
            deleteItem,
            playItem!
        ]
        
        updateTimerInBar()

        for device in experiment.bluetoothDevices {
            device.feedbackViewController = self
        }
        
        for connection in experiment.networkConnections {
            connection.feedbackViewController = self
        }

        //TabBar to switch collections
        if (experiment.viewDescriptors!.count > 1) {
            var buttons: [String] = []
            for collection in experiment.viewDescriptors! {
                buttons.append(collection.localizedLabel)
            }
            segControl = UISegmentedControl(items: buttons)
            segControl!.addTarget(self, action: #selector(switchToCollection), for: .valueChanged)
            
            segControl!.apportionsSegmentWidthsByContent = true
            
            let font: [AnyHashable : Any] = [NSAttributedStringKey.foregroundColor : kTextColor, NSAttributedStringKey.font: UIFont.preferredFont(forTextStyle: .subheadline)]
            segControl!.setTitleTextAttributes(font, for: .normal)
            segControl!.setTitleTextAttributes(font, for: .selected)
            segControl!.tintColor = kTextColor
            segControl!.backgroundColor = kTextColor
            
            //Generate new background and divider images for the segControl
            let rect = CGRect(x: 0, y: 0, width: 1, height: tabBarHeight)
            UIGraphicsBeginImageContext(rect.size)
            let ctx = UIGraphicsGetCurrentContext()
            
            //Background
            ctx!.setFillColor(kLightBackgroundColor.cgColor)
            ctx!.fill(rect)
            let bgImage = UIGraphicsGetImageFromCurrentImageContext()?.resizableImage(withCapInsets: UIEdgeInsets.zero)
            
            //Higlighted image, bg with underline
            ctx!.setFillColor(kHighlightColor.cgColor)
            ctx!.fill(CGRect(x: 0, y: tabBarHeight-2, width: 1, height: 2))
            let highlightImage = UIGraphicsGetImageFromCurrentImageContext()?.resizableImage(withCapInsets: UIEdgeInsets.zero)
            
            UIGraphicsEndImageContext()
            
            segControl!.setBackgroundImage(bgImage, for: .normal, barMetrics: .default)
            segControl!.setBackgroundImage(highlightImage, for: .selected, barMetrics: .default)
            segControl!.setDividerImage(bgImage, forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default)
            segControl!.setDividerImage(bgImage, forLeftSegmentState: .selected, rightSegmentState: .normal, barMetrics: .default)
            segControl!.setDividerImage(bgImage, forLeftSegmentState: .normal, rightSegmentState: .selected, barMetrics: .default)
            segControl!.setDividerImage(bgImage, forLeftSegmentState: .selected, rightSegmentState: .selected, barMetrics: .default)
            if #available(iOS 11.0, *) {
                segControl!.layer.maskedCorners = []
            }
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
        
    }

    class NetworkServiceRequestCallbackWrapper: NetworkServiceRequestCallback {
        let callback: ButtonViewTriggerCallback
        init(callback: ButtonViewTriggerCallback) {
            self.callback = callback
        }
        
        func requestFinished(result: NetworkServiceResult) {
            callback.finished()
        }
    }
    
    func buttonPressed(viewDescriptor: ButtonViewDescriptor, buttonViewTriggerCallback: ButtonViewTriggerCallback?) {
        var callbackHandedOver = false
        for trigger in viewDescriptor.triggers {
            for networkConnection in experiment.networkConnections {
                if networkConnection.id == trigger {
                    let callbacks: [NetworkServiceRequestCallback]
                    if let buttonViewTriggerCallback = buttonViewTriggerCallback {
                        callbacks = [NetworkServiceRequestCallbackWrapper(callback: buttonViewTriggerCallback)]
                    } else {
                        callbacks = []
                    }
                    networkConnection.execute(requestCallbacks: callbacks)
                    callbackHandedOver = true
                }
            }
        }
        for (input, output) in viewDescriptor.dataFlow {
            switch input {
            case .buffer(buffer: let buffer, usedAs: _, clear: _):
                output.replaceValues(buffer.toArray())
            case .value(let value, usedAs: _):
                output.replaceValues([value])
            }
        }
        if !callbackHandedOver {
            buttonViewTriggerCallback?.finished()
        }
    }
    
    //Force iPad-style popups (for the hint to the menu)
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    func showOptionalDialogsAndHints() {
        var hintShown = false
        
        //Ask to save the experiment locally if it has been loaded from a remote source
        if !experiment.local && !ExperimentManager.shared.experimentInCollection(crc32: experiment.crc32) {
            let al = UIAlertController(title: localize("save_locally"), message: localize("save_locally_message"), preferredStyle: .alert)
            
            al.addAction(UIAlertAction(title: localize("save_locally_button"), style: .default, handler: { _ in
                do {
                    try self.saveLocally()
                }
                catch {
                    print(error)
                }
            }))
            al.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler: nil))
            
            self.navigationController!.present(al, animated: true, completion: nil)
            
            //Show a hint for the experiment info
        } else {
            if let playItem = playItem, !hintShown {
                let defaults = UserDefaults.standard
                let key = "experiment_start_hint_dismiss_count"
                if (defaults.integer(forKey: key) < 3) {
                    let bubble = HintBubbleViewController(text: localize("start_hint"), onDismiss: {() -> Void in
                    })
                    bubble.popoverPresentationController?.delegate = self
                    bubble.popoverPresentationController?.barButtonItem = playItem
                    
                    self.present(bubble, animated: true, completion: nil)
                    hintShown = true
                }
            }
            
            if let actionItem = actionItem, !hintShown && (experiment.localizedCategory != localize("categoryRawSensor")) {
                let defaults = UserDefaults.standard
                let key = "experiment_info_hint_dismiss_count"
                if (defaults.integer(forKey: key) < 3) {
                    let bubble = HintBubbleViewController(text: localize("experimentinfo_hint"), onDismiss: {() -> Void in
                        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
                    })
                    bubble.popoverPresentationController?.delegate = self
                    bubble.popoverPresentationController?.barButtonItem = actionItem
                    
                    self.present(bubble, animated: true, completion: nil)
                    hintShown = true
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if let networkConnection = experiment.networkConnections.first {
            var sensorList: [String] = []
            for sensorInput in experiment.sensorInputs {
                sensorList.append(sensorInput.sensorType.getLocalizedName())
            }
            networkConnection.showDataAndPolicy(infoMicrophone: experiment.audioInputs.count > 0, infoLocation: experiment.gpsInputs.count > 0, infoSensorData: experiment.sensorInputs.count > 0, infoSensorDataList: sensorList, callback: self)
        } else if experiment.bluetoothDevices.count > 0 {
            connectToBluetoothDevices()
        } else {
            showOptionalDialogsAndHints()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        disconnectFromBluetoothDevices()
        disconnectFromNetworkDevices()
        
        if isMovingFromParentViewController {
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
            hud.interactionType = .blockTouchesOnHUDView
            hud.indicatorView = JGProgressHUDErrorIndicatorView()
            hud.textLabel.text = "Failed to initialize HTTP server"
            
            hud.show(in: self.view)
            
            hud.dismiss(afterDelay: 3.0)
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
            self.serverLabel!.text = localize("remoteServerActive")+"\n\(url!)"
            self.serverLabelBackground = UIView()
            self.serverLabelBackground!.backgroundColor = kLightBackgroundColor
            self.view.addSubview(self.serverLabelBackground!)
            self.view.addSubview(self.serverLabel!)
            
            updateLayout()
        }
    }
    
    private func tearDownWebServer() {
        webServer.stop()
        if let label = self.serverLabel {
            label.removeFromSuperview()
        }
        if let labelBackground = self.serverLabelBackground {
            labelBackground.removeFromSuperview()
        }
        self.serverLabel = nil
        self.serverLabelBackground = nil
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
            let al = UIAlertController(title: localize("remoteServerWarningTitle"), message: localize("remoteServerWarning"), preferredStyle: .alert)
            
            al.addAction(UIAlertAction(title: localize("ok"), style: .default, handler: { [unowned self] action in
                self.launchWebServer()
                }))
            al.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler: nil))
            
            self.navigationController!.present(al, animated: true, completion: nil)
        }
    }
    
    private func runExportFromActionSheet(_ export: ExperimentExport, singleSet: Bool) {
        let format = exportSelectionView!.selectedFormat()
        
        let HUD = JGProgressHUD(style: .dark)
        HUD.interactionType = .blockTouchesOnHUDView
        HUD.textLabel.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)
        
        HUD.show(in: navigationController!.view)
        
        runExport(export, singleSet: singleSet, format: format) { error, URL in
            if error != nil {
                HUD.indicatorView = JGProgressHUDErrorIndicatorView()
                HUD.textLabel.text = error!.localizedDescription
                HUD.dismiss(afterDelay: 3.0)
            }
            else {
                let vc = UIActivityViewController(activityItems: [URL!], applicationActivities: nil)

                vc.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItems![0]

                self.navigationController!.present(vc, animated: true) {
                    HUD.dismiss()
                }
                
                vc.completionWithItemsHandler = { _, _, _, _ in
                    do { try FileManager.default.removeItem(at: URL!) } catch {}
                }
            }
        }
    }
    
    func runExport(_ export: ExperimentExport, singleSet: Bool, format: ExportFileFormat, completion: @escaping (NSError?, URL?) -> Void) {
        export.runExport(format, singleSet: singleSet, filename: experiment.cleanedFilenameTitle) { (errorMessage, fileURL) in
            if let error = errorMessage {
                completion(NSError(domain: NSURLErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: error]), nil)
            }
            else if let URL = fileURL {
                completion(nil, URL)
            }
        }
    }
    
    internal func showExport(_ export: ExperimentExport, singleSet: Bool) {
        let alert: UIAlertController
        if export.sets.count > 0 {
            alert = UIAlertController(title: localize("export"), message: localize("pick_exportFormat"), preferredStyle: .alert)
            
            let exportAction = UIAlertAction(title: localize("export"), style: .default, handler: { [unowned self] action in
                self.runExportFromActionSheet(export, singleSet: singleSet)
                })
            
            if exportSelectionView == nil {
                exportSelectionView = ExperimentExportSetSelectionView()
            }
            
            alert.addAction(exportAction)
            
            alert.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler: nil))
            
            alert.__pt__setAccessoryView(exportSelectionView!)
        } else {
            alert = UIAlertController(title: localize("export"), message: localize("export_empty"), preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: localize("ok"), style: .default, handler: nil))
        }
        
        self.navigationController!.present(alert, animated: true, completion: nil)
    }
    
    private func showSaveState() {
        self.stopExperiment()
        
        let alert = UIAlertController(title: localize("save_state"), message: localize("save_state_message"), preferredStyle: .alert)
        
        alert.addTextField(configurationHandler: { (textField) in
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            
            let fileNameDefault = localize("save_state_default_title")
            textField.text = "\(fileNameDefault) \(dateFormatter.string(from: Date()))"
        })
        
        alert.addAction(UIAlertAction(title: localize("save_state_save"), style: .default, handler: { [unowned self] action in
            do {
                if !FileManager.default.fileExists(atPath: savedExperimentStatesURL.path) {
                    try FileManager.default.createDirectory(atPath: savedExperimentStatesURL.path, withIntermediateDirectories: false, attributes: nil)
                }

                guard let title = alert.textFields?.first?.text else {
                    return
                }

                //For now, we disable the new state serializer (saving buffers to a separate binary file)
                //until the Android version has caught up and can offer the same function
                //_ = try self.experiment.saveState(to: savedExperimentStatesURL, with: title)
                
                //Instead use the legacy state serializer for now:
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
                let fileNameDefault = self.experiment.cleanedFilenameTitle
                let filename = "\(fileNameDefault) \(dateFormatter.string(from: Date())).phyphox"
                let target = savedExperimentStatesURL.appendingPathComponent(filename)
                
                let HUD = JGProgressHUD(style: .dark)
                HUD.interactionType = .blockTouchesOnHUDView
                HUD.textLabel.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)
                
                HUD.show(in: self.navigationController!.view)
                
                LegacyStateSerializer.writeStateFile(customTitle: title, target: target.path, experiment: self.experiment, callback: {(error, file) in
                    if (error != nil) {
                        self.showError(message: error!)
                        return
                    }

                    ExperimentManager.shared.reloadUserExperiments()

                    HUD.dismiss()
                    
                    let confirmation = UIAlertController(title: localize("save_state"), message: localize("save_state_success"), preferredStyle: .alert)
                    
                    confirmation.addAction(UIAlertAction(title: localize("ok"), style: .default, handler: nil))
                    self.navigationController!.present(confirmation, animated: true, completion: nil)
                })
            }
            catch {
                self.showError(message: error.localizedDescription)
                return
            }
        }))
        
        alert.addAction(UIAlertAction(title: localize("save_state_share"), style: .default, handler: { [unowned self] action in

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
            
            let fileNameDefault = localize("save_state_default_title")
            let tmpFile = (NSTemporaryDirectory() as NSString).appendingPathComponent("\(fileNameDefault) \(dateFormatter.string(from: Date())).phyphox")
            
            guard let title = alert.textFields?.first?.text else {
                return
            }
            
            let HUD = JGProgressHUD(style: .dark)
            HUD.interactionType = .blockTouchesOnHUDView
            HUD.textLabel.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)
            
            HUD.show(in: self.navigationController!.view)
            
            LegacyStateSerializer.writeStateFile(customTitle: title, target: tmpFile, experiment: self.experiment, callback: {(error, file) in
                if (error != nil) {
                    self.showError(message: error!)
                    return
                }

                let vc = UIActivityViewController(activityItems: [file!], applicationActivities: nil)

                vc.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItems![0]

                self.navigationController!.present(vc, animated: true) {
                    HUD.dismiss()
                }

                vc.completionWithItemsHandler = { _, _, _, _ in
                    do { try FileManager.default.removeItem(atPath: tmpFile) } catch {}
                }
            })
        }))
            
        alert.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler: nil))
        
        self.navigationController!.present(alert, animated: true, completion: nil)
    }
    
    private func updateTimerInBar() {
        guard var items = self.navigationItem.rightBarButtonItems else {
            return
        }

        if let label = items.last?.customView as? UILabel {
            //The timer label is visible
            if !timerEnabled {
                //...but it should not be
                items.removeLast()
                self.navigationItem.rightBarButtonItems = items
            } else {
                //...and that is correct. Let's make sure it is up to date
                label.text = "\(self.timerDelay)s"
                label.sizeToFit()
            }
        } else {
            //The timer label is not visible
            if timerEnabled {
                //...but it should be
                let label = UILabel()
                label.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)
                label.textColor = kTextColor
                label.text = "\(self.timerDelay)s"
                label.sizeToFit()
            
                items.append(UIBarButtonItem(customView: label))
                self.navigationItem.rightBarButtonItems = items
            }
        }
    }
    
    private func showTimerOptions() {
        let alert = UIAlertController(title: localize("timedRunDialogTitle"), message: nil, preferredStyle: .alert)
        
        alert.addTextField { [unowned self] textField in
            textField.keyboardType = .decimalPad
            textField.placeholder = localize("timedRunStartDelay")
            
            textField.text = String(self.timerDelay)
        }
        
        alert.addTextField { [unowned self] textField in
            textField.keyboardType = .decimalPad
            textField.placeholder = localize("timedRunStopDelay")
            
            textField.text = String(self.timerDuration)
        }
        
        alert.addAction(UIAlertAction(title: localize("enableTimedRun"), style: .default, handler: { [unowned self, unowned alert] action in
            
            self.timerEnabled = true
            self.timerDelay = Double(alert.textFields!.first!.text ?? "0.0") ?? 0.0
            self.timerDuration = Double(alert.textFields!.last!.text ?? "0.0") ?? 0.0
            
            self.updateTimerInBar()
            }))
        
        alert.addAction(UIAlertAction(title: localize("disableTimedRun"), style: .cancel, handler: { [unowned self, unowned alert] action in
            
            self.timerEnabled = false
            self.timerDelay = Double(alert.textFields!.first!.text ?? "0.0") ?? 0.0
            self.timerDuration = Double(alert.textFields!.last!.text ?? "0.0") ?? 0.0
            
            self.updateTimerInBar()
            }))
        
        self.navigationController!.present(alert, animated: true, completion: nil)
    }
    
    @objc func action(_ item: UIBarButtonItem) {
        let alert = UIAlertController(title: localize("actions"), message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: localize("show_description"), style: .default, handler: { [unowned self] action in
            let state = self.experiment.stateTitle ?? ""
            let al = UIAlertController(title: self.experiment.localizedTitle + (state != "" ? "\n\n" + state : ""), message: self.experiment.localizedDescription, preferredStyle: .alert)
            
            for link in self.experiment.localizedLinks {
                al.addAction(UIAlertAction(title: localize(link.label), style: .default, handler: { _ in
                    UIApplication.shared.openURL(link.url)
                }))
            }
            al.addAction(UIAlertAction(title: localize("close"), style: .cancel, handler: nil))
            
            self.navigationController!.present(al, animated: true, completion: nil)
        }))
            
        if experiment.export != nil {
            alert.addAction(UIAlertAction(title: localize("export"), style: .default, handler: { [unowned self] action in
                self.showExport(self.experiment.export!, singleSet: false)
            }))
        }
        
        alert.addAction(UIAlertAction(title: localize("share"), style: .default, handler: { [unowned self] action in
            let w = UIApplication.shared.keyWindow!
            let s = UIScreen.main.scale
            UIGraphicsBeginImageContextWithOptions(w.frame.size, false, s)
            w.drawHierarchy(in: w.frame, afterScreenUpdates: false)
            let img = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            let png = UIImagePNGRepresentation(img!)!
            
            let HUD = JGProgressHUD(style: .dark)
            HUD.interactionType = .blockTouchesOnHUDView
            HUD.textLabel.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)
            
            HUD.show(in: self.navigationController!.view)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
            let tmpFile = (NSTemporaryDirectory() as NSString).appendingPathComponent("\(self.experiment.cleanedFilenameTitle) \(dateFormatter.string(from: Date())).png")
            
            do { try FileManager.default.removeItem(atPath: tmpFile) } catch {}
            do { try png.write(to: URL(fileURLWithPath: tmpFile), options: .noFileProtection) } catch {}
            let tmpFileURL = URL(fileURLWithPath: tmpFile)
            
            let vc = UIActivityViewController(activityItems: [tmpFileURL], applicationActivities: nil)
            
            vc.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItems![0]
            
            self.navigationController!.present(vc, animated: true) {
                HUD.dismiss()
            }
            
            vc.completionWithItemsHandler = { _, _, _, _ in
                do { try FileManager.default.removeItem(atPath: tmpFile) } catch {}
            }
            
        }))
            
        alert.addAction(UIAlertAction(title: localize("timedRun"), style: .default, handler: { [unowned self] action in
            self.showTimerOptions()
            }))
        
        alert.addAction(UIAlertAction(title: (webServer.running ? localize("disableRemoteServer") : localize("enableRemoteServer")), style: .default, handler: { [unowned self] action in
            self.toggleWebServer()
            }))

        for link in experiment.localizedLinks where link.highlighted {
            alert.addAction(UIAlertAction(title: localize(link.label), style: .default, handler: { _ in
                UIApplication.shared.openURL(link.url)
            }))
        }
        

        for sensor in experiment.sensorInputs {
            if sensor.sensorType == SensorType.magneticField {
                if sensor.calibrated {
                    alert.addAction(UIAlertAction(title: localize("switch_to_raw_magnetometer"), style: .default, handler: { [unowned self] action in
                        self.stopExperiment()
                        sensor.calibrated = false
                    }))
                } else {
                    alert.addAction(UIAlertAction(title: localize("switch_to_calibrated_magnetometer"), style: .default, handler: { [unowned self] action in
                        self.stopExperiment()
                        sensor.calibrated = true
                    }))
                }

                break
            }
        }
        
        if !experiment.local && !ExperimentManager.shared.experimentInCollection(crc32: experiment.crc32) {
            alert.addAction(UIAlertAction(title: localize("save_locally"), style: .default, handler: { [unowned self] action in
                try? self.saveLocally()
            }))
        }
        
        alert.addAction(UIAlertAction(title: localize("save_state"), style: .default, handler: { [unowned self] action in
            self.showSaveState()
        }))
        
        alert.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = item
        }
        
        self.navigationController?.present(alert, animated: true, completion: nil)
    }
    
    func saveLocally() throws {
        if (ExperimentManager.shared.experimentInCollection(crc32: experiment.crc32)) {
            return
        }
        try experiment.saveLocally(quiet: false, presenter: self.navigationController)
        ExperimentManager.shared.reloadUserExperiments()
    }

    @objc func stopTimerFired() {
        stopExperiment()
    }

    @objc func startTimerFired() {
        actuallyStartExperiment()
        
        experimentStartTimer?.invalidate()
        experimentStartTimer = nil
        
        let d = timerDuration
        let i = Int(d)
        
        var items = navigationItem.rightBarButtonItems
        
        guard let label = items?.last?.customView as? UILabel else { return }
        
        label.text = "\(i)s"
        label.sizeToFit()
        
        items?.removeLast()
        items?.append(UIBarButtonItem(customView: label))
        
        navigationItem.rightBarButtonItems = items
        
        func updateT() {
            guard let experimentRunTimer = experimentRunTimer else { return }

            let t = Int(round(experimentRunTimer.fireDate.timeIntervalSinceNow))

            after(1.0) {
                updateT()
            }

            label.text = "\(t)s"
            label.sizeToFit()

            var items = navigationItem.rightBarButtonItems

            items?.removeLast()
            items?.append(UIBarButtonItem(customView: label))

            navigationItem.rightBarButtonItems = items
        }
        
        after(1.0) {
            updateT()
        }
        
        experimentRunTimer = Timer.scheduledTimer(timeInterval: d, target: self, selector: #selector(stopTimerFired), userInfo: nil, repeats: false)
    }
    
    func startExperiment() {
        let defaults = UserDefaults.standard
        let key = "experiment_start_hint_dismiss_count"
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
        
        if !experiment.running {
            UIApplication.shared.isIdleTimerDisabled = true
            
            if experimentStartTimer != nil {
                experimentStartTimer!.invalidate()
                experimentStartTimer = nil
                
                updateTimerInBar()
                return
            }
            
            if timerEnabled {
                let d = timerDelay
                let i = Int(d)

                var items = navigationItem.rightBarButtonItems

                guard let label = items?.last?.customView as? UILabel else { return }

                label.text = "\(i)s"
                label.sizeToFit()

                items?.removeLast()
                items?.append(UIBarButtonItem(customView: label))

                navigationItem.rightBarButtonItems = items

                func updateT() {
                    guard let experimentStartTimer = experimentStartTimer else { return }
                    let t = Int(round(experimentStartTimer.fireDate.timeIntervalSinceNow))

                    after(1.0) {
                        updateT()
                    }

                    label.text = "\(t)s"
                    label.sizeToFit()

                    var items = navigationItem.rightBarButtonItems

                    items?.removeLast()
                    items?.append(UIBarButtonItem(customView: label))

                    navigationItem.rightBarButtonItems = items
                }

                after(1.0) {
                    updateT()
                }

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
        }
        catch {
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
                
                label.text = "\(self.timerDelay)s"
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
        let al = UIAlertController(title: localize("clear_data"), message: localize("clear_data_question"), preferredStyle: .alert)
        
        al.addAction(UIAlertAction(title: localize("clear"), style: .default, handler: { [unowned self] action in
            self.clearData()
        }))
        al.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler: nil))
        
        self.navigationController!.present(al, animated: true, completion: nil)
    }
    
    func clearData() {
        self.stopExperiment()
        self.experiment.clear()
        
        self.webServer.forceFullUpdate = true //The next time, the webinterface requests buffers, we need to send a full update, so the now empty buffers can be recognized
        
        for section in self.viewModules {
            for view in section {
                if let graphView = view as? GraphViewModule {
                    graphView.clearData()
                }
            }
        }
    }

    func connectToBluetoothDevices() {
        
        if experiment.bluetoothDevices.count == 1, let input = experiment.bluetoothDevices.first {
            if input.deviceAddress != nil {
                input.stopExperimentDelegate = self
                input.scanToConnect()
                if (experiment.networkConnections.count > 0) {
                    connectToNetworkDevices()
                } else {
                    showOptionalDialogsAndHints()
                }
                return
            }
        }
        
        for device in experiment.bluetoothDevices {
            if device.deviceAddress == nil {
                device.stopExperimentDelegate = self
                device.showScanDialog(dismissDelegate: self)
                
                return
            }
        }
        
        //No more dialogs shown. Now show any other dialog that had to wait.
        if (experiment.networkConnections.count > 0) {
            connectToNetworkDevices()
        } else {
            showOptionalDialogsAndHints()
        }
    }
    
    func bluetoothScanDialogDismissed() {
        connectToBluetoothDevices()
    }
    
    func disconnectFromBluetoothDevices(){
        for device in experiment.bluetoothDevices {
            device.disconnect()
        }
    }
    
    func connectToNetworkDevices() {
        for device in experiment.networkConnections {
            if device.specificAddress == nil {
                device.connect(dismissDelegate: self)
                return
            }
        }
        showOptionalDialogsAndHints()
    }
    
    func networkScanDialogDismissed() {
        connectToNetworkDevices()
    }
    
    func disconnectFromNetworkDevices() {
        for device in experiment.networkConnections {
            device.disconnect()
        }
    }
    
    func dataPolicyInfoDismissed() {
        if experiment.bluetoothDevices.count > 0 {
            connectToBluetoothDevices()
        } else {
            connectToNetworkDevices()
        }
    }
}
