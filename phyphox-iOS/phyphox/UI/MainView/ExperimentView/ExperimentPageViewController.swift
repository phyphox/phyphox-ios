//
//  ExperimentPageViewController.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 30.05.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation
import GCDWebServers
import SwiftUI

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
    
    var hintBubble: HintBubbleViewController? = nil
    
    let pageViewControler: UIPageViewController = UIPageViewController(transitionStyle: UIPageViewController.TransitionStyle.scroll, navigationOrientation: UIPageViewController.NavigationOrientation.horizontal, options: nil)
    
    var serverLabel: UITextView? = nil
    var serverLabelBackground: UIView? = nil
    var serverQRIcon: UIButton? = nil
    
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
    private struct TimerBeep {
        var countdown = false
        var start = false
        var running = false
        var stop = false
    }
    private var timerBeep = TimerBeep()
    private let countdownFormatter = NumberFormatter()
    
    private var experimentStartTimer: Timer?
    private var experimentRunTimer: Timer?
    
    private var exportSelectionView: ExperimentExportSetSelectionView?
    private var timedRunDialogView: ExperimentTimedRunDialogView?
    
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
        
        self.timerEnabled = experiment.analysis.timedRun
        self.timerDelay = experiment.analysis.timedRunStartDelay
        self.timerDuration = experiment.analysis.timedRunStopDelay
        
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
        
        let backButton =  UIBarButtonItem(title: "‹", style: .plain, target: self, action: #selector(leaveExperiment))
        backButton.setTitleTextAttributes([NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 32)], for: .normal)
        navigationItem.leftBarButtonItem = backButton
        
        webServer.delegate = self
        experiment.analysisDelegate = self
        
        countdownFormatter.minimumFractionDigits = 1
        
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
        
        if isMovingToParent {
            experiment.willBecomeActive {
                DispatchQueue.main.async {
                    self.navigationController?.popToRootViewController(animated: true)
                }
            }
        }
        
        guard let navBar = self.navigationController?.navigationBar else {
            return
        }
        if #available(iOS 13, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = kHighlightColor
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: kTextColor]
            navBar.standardAppearance = appearance;
            navBar.scrollEdgeAppearance = navBar.standardAppearance
        } else {
            navBar.barTintColor = kHighlightColor
            navBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: kTextColor]
            navBar.isTranslucent = false
        }
    }
    
    func updateSegControlDesign() {
        let font: [NSAttributedString.Key : Any] = [NSAttributedString.Key.foregroundColor : SettingBundleHelper.getTextColorWhenDarkModeNotSupported() , NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .subheadline)]
        segControl!.setTitleTextAttributes(font, for: .normal)
        segControl!.setTitleTextAttributes(font, for: .selected)
        
        segControl!.tintColor = UIColor(named: "textColor")
        segControl!.backgroundColor = UIColor(named: "textColor")
        
        //Generate new background and divider images for the segControl
        let rect = CGRect(x: 0, y: 0, width: 1, height: tabBarHeight)
        UIGraphicsBeginImageContext(rect.size)
        let ctx = UIGraphicsGetCurrentContext()
        
        //Background
        ctx!.setFillColor(UIColor(named: "lightBackgroundColor")?.cgColor ?? kLightBackgroundColor.cgColor)
        ctx!.fill(rect)
        let bgImage = UIGraphicsGetImageFromCurrentImageContext()?.resizableImage(withCapInsets: UIEdgeInsets.zero)
        
        //Higlighted image, bg with underline
        ctx!.setFillColor(UIColor(named: "highlightColor")?.cgColor ?? kHighlightColor.cgColor)
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
        
        refreshTheAdjustedGraphColorForLightMode()
        
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
            segControl = UIExperimentTabControl(items: buttons)
            segControl!.addTarget(self, action: #selector(switchToCollection), for: .valueChanged)
            
            segControl!.apportionsSegmentWidthsByContent = true
            
            updateSegControlDesign()
            segControl!.sizeToFit()
            
            tabBar = UIScrollView()
            tabBar!.frame = CGRect(x: 0, y: self.topLayoutGuide.length, width: self.view.frame.width, height: tabBarHeight)
            tabBar!.contentSize = segControl!.frame.size
            tabBar!.showsHorizontalScrollIndicator = false
            tabBar!.autoresizingMask = .flexibleWidth
            tabBar!.backgroundColor = SettingBundleHelper.getLightBackgroundColorWhenDarkModeNotSupported()
            tabBar!.addSubview(segControl!)
            
            self.view.addSubview(tabBar!)
            
        }
        
        pageViewControler.delegate = self
        pageViewControler.dataSource = self
        pageViewControler.setViewControllers([experimentViewControllers[0]], direction: .forward, animated: false, completion: nil)
        pageViewControler.view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        updateLayout()
        
        self.addChild(pageViewControler)
        self.view.addSubview(pageViewControler.view)
        
        pageViewControler.didMove(toParent: self)
        
        updateSelectedViewCollection()
        
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateSelectedViewCollection()
        refreshTheAdjustedGraphColorForLightMode()
        updateSegControlDesign()
        tabBar!.backgroundColor = SettingBundleHelper.getLightBackgroundColorWhenDarkModeNotSupported()
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
            case .buffer(buffer: let buffer, data: _, usedAs: _, clear: _):
                output.replaceValues(buffer.toArray())
                output.triggerUserInput()
            case .value(let value, usedAs: _):
                output.replaceValues([value])
                output.triggerUserInput()
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
        
        //Ask to save the experiment locally if it has been loaded from a remote source
        if !experiment.local && !ExperimentManager.shared.experimentInCollection(crc32: experiment.crc32) {
            UIAlertController.PhyphoxUIAlertBuilder()
                .title(title: localize("save_locally"))
                .message(message: localize("save_locally_message"))
                .preferredStyle(style: .alert)
                .addActionWithTitle(localize("save_locally_button"), style: .default, handler: { _ in
                    do {
                        try self.saveLocally()
                    }
                    catch {
                        print(error)
                    }
                })
                .addCancelAction()
                .show(in: self.navigationController!, animated: true)
            
            //Show a hint for the experiment info
        } else {
            if let playItem = playItem, hintBubble == nil {
                let defaults = UserDefaults.standard
                let key = "experiment_start_hint_dismiss_count"
                if (defaults.integer(forKey: key) < 3) {
                    hintBubble = HintBubbleViewController(text: localize("start_hint"), onDismiss: {() -> Void in
                    })
                    guard let hintBubble = hintBubble else {
                        return
                    }
                    hintBubble.popoverPresentationController?.delegate = self
                    hintBubble.popoverPresentationController?.barButtonItem = playItem
                    
                    self.present(hintBubble, animated: true, completion: nil)
                }
            }
            
            if let actionItem = actionItem, hintBubble == nil && (experiment.localizedCategory != localize("categoryRawSensor")) {
                let defaults = UserDefaults.standard
                let key = "experiment_info_hint_dismiss_count"
                if (defaults.integer(forKey: key) < 3) {
                    hintBubble = HintBubbleViewController(text: localize("experimentinfo_hint"), onDismiss: {() -> Void in
                        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
                    })
                    guard let hintBubble = hintBubble else {
                        return
                    }
                    hintBubble.popoverPresentationController?.delegate = self
                    hintBubble.popoverPresentationController?.barButtonItem = actionItem
                    
                    self.present(hintBubble, animated: true, completion: nil)
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if #available(iOS 14.0, *) {
            for vc in experimentViewControllers {
                for view in vc.modules {
                    if let depthGUI = view as? ExperimentDepthGUIView {
                        guard let session = experiment.depthInput?.session as? ExperimentDepthInputSession else {
                            continue
                        }
                        session.attachDelegate(delegate: depthGUI)
                        depthGUI.depthGUISelectionDelegate = session
                    }
                }
            }
        }
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
        
        if #available(iOS 14.0, *) {
            if let session = experiment.depthInput?.session as? ExperimentDepthInputSession {
                session.stopSession()
            }
        }
        disconnectFromBluetoothDevices()
        disconnectFromNetworkDevices()
        
        if isMovingFromParent {
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
        let direction = selectedViewCollection < sender.selectedSegmentIndex ? UIPageViewController.NavigationDirection.forward : UIPageViewController.NavigationDirection.reverse
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
    
    private var remoteUrl: String = ""
    
    private func launchWebServer() {
        experiment.setKeepScreenOn(true)
        if !webServer.start() {
            let hud = JGProgressHUD(style: .dark)
            hud.interactionType = .blockTouchesOnHUDView
            hud.indicatorView = JGProgressHUDErrorIndicatorView()
            hud.textLabel.text = "Failed to initialize HTTP server"
            
            hud.show(in: self.view)
            
            hud.dismiss(afterDelay: 3.0)
        }
        else {
            remoteUrl = webServer.server!.serverURL?.absoluteString ?? ""
            var url = remoteUrl
            if url.last == "/" {
                url = String(url.dropLast())
            }
            //This does not work when using the mobile hotspot, so if we did not get a valid address, we will have to determine it ourselves...
            if url == "" {
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
                    if webServer.port != 80 {
                        url = "http://\(ip!):\(webServer.port)"
                    } else {
                        url = "http://\(ip!)"
                    }
                } else {
                    url = "Error: No active network."
                }
            }
            
            //UITextView is used instead of UILabel as it doesnot support select and copy feature in text
            self.serverLabel = UITextView()
            self.serverLabel!.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body)
            self.serverLabel!.textColor = UIColor(named: "textColor") ?? kTextColor
            self.serverLabel!.backgroundColor = UIColor(named: "lightBackgroundColor") ?? kLightBackgroundColor
            self.serverLabel!.text = localize("remoteServerActive")+"\n\(url)"
            self.serverLabel?.isEditable = false
            
            //To force textlabel to fit its size as per its length and no. of lines
            self.serverLabel!.translatesAutoresizingMaskIntoConstraints = true
            self.serverLabel!.sizeToFit()
            self.serverLabel!.isScrollEnabled = false
            
            //To hide keyboard on touch
            self.serverLabel!.inputView = UIView()
            self.serverLabel!.inputAccessoryView = UIView()
            
            self.serverQRIcon = UIButton(type: .system)
            let image = UIImage(named: "new_experiment_qr")!.resize(size: CGSize(width: 30, height: 30))
            self.serverQRIcon?.setImage(image, for: .normal)
            self.serverQRIcon?.addTarget(self, action: #selector(showQr), for: .touchUpInside)
            self.serverQRIcon?.imageView?.contentMode = .scaleAspectFit
           
            
            self.serverLabelBackground = UIView()
            self.serverLabelBackground!.backgroundColor = UIColor(named: "lightBackgroundColor") ?? kLightBackgroundColor
            self.view.addSubview(self.serverLabelBackground!)
            self.view.addSubview(self.serverLabel!)
            self.view.addSubview(self.serverQRIcon!)
            
            // set view1 constraints
            self.serverQRIcon!.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                self.serverQRIcon!.trailingAnchor.constraint(equalTo: self.serverLabelBackground!.trailingAnchor, constant: -20.0),
                self.serverQRIcon!.bottomAnchor.constraint(equalTo: self.serverLabelBackground!.bottomAnchor, constant: -25.0)
            
            ])
            
            updateLayout()
        }
    }
    
    @objc func showQr(){
        let data = remoteUrl.data(using: .utf8)
        let qrFilter = CIFilter(name: "CIQRCodeGenerator")
        
        qrFilter?.setValue(data, forKey: "inputMessage")
        qrFilter?.setValue("Q", forKey: "inputCorrectionLevel")
        
        let qrImage = qrFilter?.outputImage
        
        let displayImage = UIImage(ciImage: qrImage!).resize(size: CGSize(width: 150, height: 150))
        
        let imageView = UIImageView(image: displayImage)
        
        showQrInDialog(imageView: imageView)
        
        
    }
    
    @objc func showQrInDialog(imageView: UIImageView) {
        imageView.contentMode = .scaleAspectFit
        
        let alertController = UIAlertController(title: localize("showQRCodeForRemoteURL"), message: nil, preferredStyle: .alert)
        alertController.view.addSubview(imageView)
        
        // Set the image view's constraints
        alertController.view.heightAnchor.constraint(equalToConstant: 300).isActive = true
        alertController.view.widthAnchor.constraint(equalToConstant: 300).isActive = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.centerXAnchor.constraint(equalTo: alertController.view.centerXAnchor).isActive = true
        imageView.centerYAnchor.constraint(equalTo: alertController.view.centerYAnchor).isActive = true
       
        let closeButton = UIAlertAction(title: localize("cancel"), style: .default, handler: nil)
        alertController.addAction(closeButton)
        
        present(alertController, animated: true, completion: nil)
    }
    
    private func tearDownWebServer() {
        webServer.stop()
        if let label = self.serverLabel {
            label.removeFromSuperview()
        }
        if let labelBackground = self.serverLabelBackground {
            labelBackground.removeFromSuperview()
        }
        if let button = self.serverQRIcon {
            button.removeFromSuperview()
        }
        self.serverLabel = nil
        self.serverLabelBackground = nil
        self.serverQRIcon = nil
        updateLayout()
        if (!self.experiment.running) {
            experiment.setKeepScreenOn(false)
        }
    }
    
    private func toggleWebServer() {
        if webServer.running {
            tearDownWebServer()
        }
        else {
            UIAlertController.PhyphoxUIAlertBuilder()
                .title(title: localize("remoteServerWarningTitle"))
                .message(message: localize("remoteServerWarning"))
                .preferredStyle(style: .alert)
                .addActionWithTitle(localize("ok"), style: .default, handler: { [unowned self] action in
                    self.launchWebServer()
                })
                .addCancelAction()
                .show(in: self.navigationController!, animated: true)
        }
    }
    
    private func runExportFromActionSheet(_ export: ExperimentExport, singleSet: Bool) {
        let format = exportSelectionView!.selectedFormat()
        
        let HUD = JGProgressHUD(style: .dark)
        HUD.interactionType = .blockTouchesOnHUDView
        HUD.textLabel.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline)
        
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
        export.runExport(format, singleSet: singleSet, filename: experiment.cleanedFilenameTitle, timeReference: experiment.timeReference) { (errorMessage, fileURL) in
            if let error = errorMessage {
                completion(NSError(domain: NSURLErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: error]), nil)
            }
            else if let URL = fileURL {
                completion(nil, URL)
            }
        }
    }
    
    internal func showExport(_ export: ExperimentExport, singleSet: Bool) {
        if export.sets.count > 0 {
            let exportAction = UIAlertAction(title: localize("export"), style: .default, handler: { [unowned self] action in
                self.runExportFromActionSheet(export, singleSet: singleSet)
            })
            
            if exportSelectionView == nil {
                exportSelectionView = ExperimentExportSetSelectionView()
            }
            
            
            UIAlertController.PhyphoxUIAlertBuilder()
                .title(title: localize("export"))
                .message(message: localize("pick_exportFormat"))
                .preferredStyle(style: .alert)
                .addDefinedAction(action: exportAction)
                .addCancelAction()
                .setAccessoryView(accessoryView: exportSelectionView!)
                .show(in: self.navigationController!, animated: true)
            
        } else {
            
            UIAlertController.PhyphoxUIAlertBuilder()
                .title(title: localize("export"))
                .message(message: localize("export_empty"))
                .preferredStyle(style: .alert)
                .addOkAction()
                .show(in: self.navigationController!, animated: true)
            
        }
        
    }
    
    private func showSaveState() {
        self.stopExperiment()
        
        let alertBuilder = UIAlertController.PhyphoxUIAlertBuilder()
        alertBuilder.title(title: localize("save_state"))
            .message(message: localize("save_state_message"))
            .preferredStyle(style: .alert)
            .addTextField(configHandler: { (textField) in
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .short
                
                let fileNameDefault = localize("save_state_default_title")
                textField.text = "\(fileNameDefault) \(dateFormatter.string(from: Date()))"
            })
            .addActionWithTitle(localize("save_state_save"), style: .default, handler: { [unowned self] action in
                if let title = alertBuilder.getTextFieldValue().text {
                    saveTheState(title: title)
                }
            })
            .addActionWithTitle(localize("save_state_share"), style: .default, handler: { [unowned self] action in
                if let title = alertBuilder.getTextFieldValue().text {
                    shareTheState(title: title)
                }
            })
            .addCancelAction()
            .show(in: self.navigationController!, animated: true)
        
    }
    
    private func showHUDProgressWidget() -> JGProgressHUD{
        let HUD = JGProgressHUD(style: .dark)
        HUD.interactionType = .blockTouchesOnHUDView
        HUD.textLabel.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline)
        HUD.show(in: self.navigationController!.view)
        return HUD
    }
    
    private func createTimeStampedFileNameWith(fileNameDefault: String) -> String
    {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return "\(fileNameDefault) \(dateFormatter.string(from: Date())).phyphox"
    }
    
    private func saveTheState(title: String){
        do {
            if !FileManager.default.fileExists(atPath: savedExperimentStatesURL.path) {
                try FileManager.default.createDirectory(atPath: savedExperimentStatesURL.path, withIntermediateDirectories: false, attributes: nil)
            }
            
            //For now, we disable the new state serializer (saving buffers to a separate binary file)
            //until the Android version has caught up and can offer the same function
            //_ = try self.experiment.saveState(to: savedExperimentStatesURL, with: title)
            
            //Instead use the legacy state serializer for now:
            let fileName = createTimeStampedFileNameWith(fileNameDefault: self.experiment.cleanedFilenameTitle)
            let target = savedExperimentStatesURL.appendingPathComponent(fileName)
            
            let HUD = showHUDProgressWidget()
            
            LegacyStateSerializer.writeStateFile(customTitle: title, target: target.path, experiment: self.experiment, callback: {(error, file) in
                if (error != nil) {
                    self.showError(message: error!)
                    return
                }
                
                ExperimentManager.shared.reloadUserExperiments()
                
                HUD.dismiss()
                
                UIAlertController.PhyphoxUIAlertBuilder()
                    .title(title: localize("save_state"))
                    .message(message: localize("save_state_success"))
                    .preferredStyle(style: .alert)
                    .addOkAction()
                    .show(in: self.navigationController!, animated: true)
            })
        }
        catch {
            self.showError(message: error.localizedDescription)
            return
        }
    }
    
    private func shareTheState(title: String){
        let fileName = createTimeStampedFileNameWith(fileNameDefault: localize("save_state_default_title"))
        let tmpFile = (NSTemporaryDirectory() as NSString).appendingPathComponent(fileName)
        
        let HUD = showHUDProgressWidget()
        
        
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
                label.text = countdownFormatter.string(from: self.timerDelay as NSNumber)
                label.sizeToFit()
            }
        } else {
            //The timer label is not visible
            if timerEnabled {
                //...but it should be
                let label = UILabel()
                label.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline)
                label.textColor = kTextColor
                label.text = countdownFormatter.string(from: self.timerDelay as NSNumber)
                label.sizeToFit()
                
                items.append(UIBarButtonItem(customView: label))
                self.navigationItem.rightBarButtonItems = items
            }
        }
    }
    
    private func showTimerOptions() {
        let alert = UIAlertController(title: localize("timedRunDialogTitle"), message: nil, preferredStyle: .alert)
        
        if timedRunDialogView == nil {
            timedRunDialogView = ExperimentTimedRunDialogView(delay: self.timerDelay, duration: self.timerDuration, countdown: timerBeep.countdown, start: timerBeep.start, running: timerBeep.running, stop: timerBeep.stop)
        }
        
        alert.__pt__setAccessoryView(timedRunDialogView!)
        
        alert.addAction(UIAlertAction(title: localize("enableTimedRun"), style: .default, handler: { [unowned self] action in
            
            self.timerEnabled = true
            self.timerDelay = Double(timedRunDialogView?.delay.tf.text?.replacingOccurrences(of: ",", with: ".") ?? "0.0") ?? 0.0
            self.timerDuration = Double(timedRunDialogView?.duration.tf.text?.replacingOccurrences(of: ",", with: ".") ?? "0.0") ?? 0.0
            self.timerBeep.countdown = timedRunDialogView?.beeperCountdown.sw.isOn ?? false
            self.timerBeep.start = timedRunDialogView?.beeperStart.sw.isOn ?? false
            self.timerBeep.running = timedRunDialogView?.beeperRunning.sw.isOn ?? false
            self.timerBeep.stop = timedRunDialogView?.beeperStop.sw.isOn ?? false
            
            self.updateTimerInBar()
        }))
        
        alert.addAction(UIAlertAction(title: localize("disableTimedRun"), style: .cancel, handler: { [unowned self] action in
            
            self.timerEnabled = false
            self.timerDelay = Double(timedRunDialogView?.delay.tf.text?.replacingOccurrences(of: ",", with: ".") ?? "0.0") ?? 0.0
            self.timerDuration = Double(timedRunDialogView?.duration.tf.text?.replacingOccurrences(of: ",", with: ".") ?? "0.0") ?? 0.0
            self.timerBeep.countdown = timedRunDialogView?.beeperCountdown.sw.isOn ?? false
            self.timerBeep.start = timedRunDialogView?.beeperStart.sw.isOn ?? false
            self.timerBeep.running = timedRunDialogView?.beeperRunning.sw.isOn ?? false
            self.timerBeep.stop = timedRunDialogView?.beeperStop.sw.isOn ?? false
            
            self.updateTimerInBar()
        }))
        
        self.navigationController!.present(alert, animated: true, completion: nil)
    }
    
    @objc func action(_ item: UIBarButtonItem) {
        hintBubble?.dismiss(animated: true, completion: nil)
        let alert = UIAlertController(title: localize("actions"), message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: localize("show_description"), style: .default, handler: { [unowned self] action in
            let state = self.experiment.stateTitle ?? ""
            let al = UIAlertController(title: self.experiment.localizedTitle + (state != "" ? "\n\n" + state : ""), message: self.experiment.localizedDescription, preferredStyle: .alert)
            
            for link in self.experiment.localizedLinks {
                al.addAction(UIAlertAction(title: localize(link.label), style: .default, handler: { _ in
                    UIApplication.shared.open(link.url)
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
            let png = img!.pngData()!
            
            let HUD = JGProgressHUD(style: .dark)
            HUD.interactionType = .blockTouchesOnHUDView
            HUD.textLabel.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline)
            
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
                UIApplication.shared.open(link.url)
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
        if timerBeep.stop {
            experiment.audioEngine?.beep(frequency: 800, duration: 0.5)
        }
        stopExperiment()
    }
    
    @objc func startTimerFired() {
        if timerBeep.start {
            experiment.audioEngine?.beep(frequency: 1000, duration: 0.5)
        }
        actuallyStartExperiment()
        
        experimentStartTimer?.invalidate()
        experimentStartTimer = nil
        
        let d = timerDuration
        var nextBeep = floor(d-0.6)
        
        var items = navigationItem.rightBarButtonItems
        
        guard let label = items?.last?.customView as? UILabel else { return }
        
        label.text = countdownFormatter.string(from: d as NSNumber)
        label.sizeToFit()
        
        items?.removeLast()
        items?.append(UIBarButtonItem(customView: label))
        
        navigationItem.rightBarButtonItems = items
        
        func updateT() {
            guard let experimentRunTimer = experimentRunTimer else { return }
            
            let dt = experimentRunTimer.fireDate.timeIntervalSinceNow
            if dt <= nextBeep && nextBeep > 0 {
                nextBeep -= 1
                if timerBeep.running {
                    experiment.audioEngine?.beep(frequency: 1000, duration: 0.1)
                }
            }
            
            after(0.02) {
                updateT()
            }
            
            label.text = countdownFormatter.string(from: dt as NSNumber)
            label.sizeToFit()
            
            var items = navigationItem.rightBarButtonItems
            
            items?.removeLast()
            items?.append(UIBarButtonItem(customView: label))
            
            navigationItem.rightBarButtonItems = items
        }
        
        after(0.02) {
            updateT()
        }
        
        experimentRunTimer = Timer.scheduledTimer(timeInterval: d, target: self, selector: #selector(stopTimerFired), userInfo: nil, repeats: false)
    }
    
    func startExperiment() {
        let defaults = UserDefaults.standard
        let key = "experiment_start_hint_dismiss_count"
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
        
        if !experiment.running {
            experiment.setKeepScreenOn(true)
            
            if experimentStartTimer != nil {
                experimentStartTimer!.invalidate()
                experimentStartTimer = nil
                
                updateTimerInBar()
                return
            }
            
            if timerEnabled {
                if timerBeep.countdown || timerBeep.start || timerBeep.stop || timerBeep.running {
                    do {
                        try experiment.startAudio(countdown: true, stopExperimentDelegate: self)
                    } catch {
                        showError(message: "Could not start experiment \(error).")
                        experiment.stop()
                        return
                    }
                }
                
                let d = timerDelay
                var nextBeep = floor(d-0.5)
                
                var items = navigationItem.rightBarButtonItems
                
                guard let label = items?.last?.customView as? UILabel else { return }
                
                label.text = countdownFormatter.string(from: d as NSNumber)
                label.sizeToFit()
                
                items?.removeLast()
                items?.append(UIBarButtonItem(customView: label))
                
                navigationItem.rightBarButtonItems = items
                
                func updateT() {
                    guard let experimentStartTimer = experimentStartTimer else { return }
                    
                    let dt = experimentStartTimer.fireDate.timeIntervalSinceNow
                    if dt <= nextBeep && nextBeep > 0 {
                        nextBeep -= 1
                        if timerBeep.countdown {
                            experiment.audioEngine?.beep(frequency: 800, duration: 0.1)
                        }
                    }
                    
                    after(0.02) {
                        updateT()
                    }
                    
                    label.text = countdownFormatter.string(from: dt as NSNumber)
                    label.sizeToFit()
                    
                    var items = navigationItem.rightBarButtonItems
                    
                    items?.removeLast()
                    items?.append(UIBarButtonItem(customView: label))
                    
                    navigationItem.rightBarButtonItems = items
                }
                
                after(0.2) {
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
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default))
        present(alert, animated: true)
    }
    
    func actuallyStartExperiment() {
        do {
            try experiment.start(stopExperimentDelegate: self)
        } catch AudioEngine.AudioEngineError.NoInput {
            showError(message: "Could not start experiment: No microphone available.")
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
                experiment.setKeepScreenOn(false)
            }
            
            var items = navigationItem.rightBarButtonItems!
            
            if experimentRunTimer != nil {
                experimentRunTimer!.invalidate()
                experimentRunTimer = nil
                
                let label = items.last!.customView! as! UILabel
                
                label.text = countdownFormatter.string(from: self.timerDelay as NSNumber)
                label.sizeToFit()
                
                items.removeLast()
                items.append(UIBarButtonItem(customView: label))
                
            }
            
            experiment.stop()
            
            items[2] = UIBarButtonItem(barButtonSystemItem: .play, target: self, action: #selector(toggleExperiment))
            
            navigationItem.rightBarButtonItems = items
        }
    }
    
    @objc func leaveExperiment() {
        if experiment.timeReference.getExperimentTime() > 10 {
            let al = UIAlertController(title: localize("leave_experiment"), message: localize("leave_experiment_question"), preferredStyle: .alert)
            
            al.addAction(UIAlertAction(title: localize("leave"), style: .default, handler: { [unowned self] action in
                self.navigationController?.popViewController(animated: true)
            }))
            al.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler: nil))
            
            self.navigationController!.present(al, animated: true, completion: nil)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    @objc func toggleExperiment() {
        hintBubble?.dismiss(animated: true, completion: nil)
        if experiment.running {
            stopExperiment()
        }
        else {
            startExperiment()
        }
    }
    
    @objc func clearDataDialog() {
        hintBubble?.dismiss(animated: true, completion: nil)
        
        let al = UIAlertController(title: localize("clear_data"), message: localize("clear_data_question"), preferredStyle: .alert)
        
        al.addAction(UIAlertAction(title: localize("clear"), style: .default, handler: { [unowned self] action in
            self.clearData()
        }))
        al.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler: nil))
        
        self.navigationController!.present(al, animated: true, completion: nil)
    }
    
    func clearData() {
        self.stopExperiment()
        self.experiment.clear(byUser: true)
        
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
    
    func refreshTheAdjustedGraphColorForLightMode(){
        if #available(iOS 12.0, *) {
            if(SettingBundleHelper.getAppMode() == Utility.LIGHT_MODE ||
               UIScreen.main.traitCollection.userInterfaceStyle == .light){
                if #available(iOS 13.0, *) {
                    view.overrideUserInterfaceStyle = .light
                } else {
                    // Fallback on earlier versions
                }
            }
        } else {
            // Fallback on earlier versions
        }
    }
}

extension ExperimentPageViewController: ExperimentAnalysisDelegate {
    func analysisWillUpdate(_: ExperimentAnalysis) {
        for module in viewModules.flatMap({ $0 }) {
            if let analysisLimitedViewModule = module as? AnalysisLimitedViewModule {
                analysisLimitedViewModule.analysisRunning = true
            }
        }
    }
    
    func analysisDidUpdate(_: ExperimentAnalysis) {
        for module in viewModules.flatMap({ $0 }) {
            if let analysisLimitedViewModule = module as? AnalysisLimitedViewModule {
                analysisLimitedViewModule.analysisRunning = false
            }
        }
    }
}

