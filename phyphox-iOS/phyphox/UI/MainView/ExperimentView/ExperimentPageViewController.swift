//
//  ExperimentPageViewController.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 30.05.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import AVFoundation
import Foundation
import GCDWebServer

protocol ExportDelegate {
    func showExport(_ export: ExperimentExport, singleSet: Bool)
}

protocol StopExperimentDelegate {
    func stopExperiment()
}

final class ExperimentPageViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIPopoverPresentationControllerDelegate, ExperimentWebServerDelegate, ExportDelegate, StopExperimentDelegate, BluetoothScanDialogDismissedDelegate, NetworkScanDialogDismissedDelegate, NetworkConnectionDataPolicyInfoDelegate, UpdateConnectedDeviceDelegate{
    
    var actionItem: UIBarButtonItem?
    var playItem: UIBarButtonItem?
    
    var segControl: UISegmentedControl? = nil
    var tabBar: UIScrollView? = nil
    var tabBarHeight : CGFloat = 30 //Adjusted to the native segmented control's height at creation
    
    var hintTooltip: HintTooltipView? = nil

    //Floating countdown display for timed runs, shown at the top right of the content area. It used
    //to be a UIBarButtonItem label, but the iOS 26 glass bar buttons left the already tight
    //navigation bar without any room for the experiment title once the timer appeared.
    private var timerDisplay: UIView? = nil
    private var timerDisplayBackdrop: UIVisualEffectView? = nil
    private var timerLabel: UILabel? = nil
    private var photosensitivityWarningShown = false
    private var hasCompletedInitialPermissionCheck = false
    private var startHintShown = false
    private var infoHintShown = false
    
    let pageViewControler: UIPageViewController = UIPageViewController(transitionStyle: UIPageViewController.TransitionStyle.scroll, navigationOrientation: UIPageViewController.NavigationOrientation.horizontal, options: nil)
    
    var serverLabel: UITextView? = nil
    var serverLabelBackground: UIView? = nil
    var serverQRIcon: UIButton? = nil
    
    let experiment: Experiment
    
    var experimentViewControllers: [ExperimentViewController] = []
    
    let webServer: ExperimentWebServer
    
    private var viewModules: [[ExperimentModule]]
    
    var numOfConnectedDevices = 0
    
    var bluetoothStatusBar: ConnectedBluetoothDevicesViewController? = nil

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
        
        var modules: [[ExperimentModule]] = []
        
        if let descriptors = experiment.viewDescriptors {
            for collection in descriptors {
                let m = ExperimentViewModuleFactory.createViews(collection, resourceFolder: experiment.resourceFolder)
                
                modules.append(m)
                
                experimentViewControllers.append(ExperimentViewController(modules: m))
            }
        }
        
        viewModules = modules
        
        selectedViewCollection = 0
        
        super.init(nibName: nil, bundle: nil)
        
        experimentViewControllers.first?.active = true
        
        for module in viewModules.flatMap({ $0 }) {
            if let button = module.view as? ExperimentButtonView {
                button.buttonTappedCallback = { [weak self, weak button] in
                    guard let button = button else { return }
                    self?.buttonPressed(viewDescriptor: button.descriptor, buttonViewTriggerCallback: button)
                }
            }
            if let exportingViewModule = module.view as? ExportingViewModule {
                exportingViewModule.exportDelegate = self
            }
        }
        
        ExperimentBluetoothDevice.updateDelegate = self
        
        
        self.navigationItem.title = experiment.displayTitle //Keeps the accessibility name and back label

        //With the iOS 26 glass bar buttons there is little width left for the title, and the
        //default bar title only truncates. This label shrinks the font to fit and, for very long
        //titles, wraps onto a second line — the title is what identifies an experiment on student
        //screenshots, so it should stay readable.
        installFittingTitle()

        let backButton =  UIBarButtonItem(title: "‹", style: .plain, target: self, action: #selector(leaveExperiment))
        backButton.setTitleTextAttributes([NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 32)], for: .normal)
        navigationItem.leftBarButtonItem = backButton
        
        webServer.delegate = self
        experiment.analysisDelegate = self

        experiment.flashlightOutput?.onThermalWarning = { [weak self] in
            guard let self = self else { return }
            UIAlertController.PhyphoxUIAlertBuilder()
                .title(title: localize("device_overheating"))
                .message(message: localize("device_heating_serious"))
                .preferredStyle(style: .alert)
                .addOkAction()
                .show(in: self.topMostViewController, animated: true)
        }
        
        countdownFormatter.minimumFractionDigits = 1
        
        defer {
            NotificationCenter.default.addObserver(self, selector: #selector(ExperimentPageViewController.onResignActiveNotification), name: .resignActiveNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(ExperimentPageViewController.onDidBecomeActiveNotification), name: .didBecomeActiveNotification, object: nil)
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
        
        guard let navBar = self.navigationController?.navigationBar else {
            return
        }
        if #available(iOS 13, *) {
            //Per-item appearance: UIKit cross-fades between the collection's transparent
            //large-title bar and this opaque branded bar during the push/pop transition. Mutating
            //the shared bar's appearance here instead paints the orange background onto the bar
            //while it still has the collection's large-title height — a tall orange flash on push.
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = kHighlightColor
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: kTextColor]
            navigationItem.standardAppearance = appearance
            navigationItem.scrollEdgeAppearance = appearance
            navigationItem.compactAppearance = appearance
            navBar.tintColor = kTextColor
            navigationItem.largeTitleDisplayMode = .never
        } else {
            navBar.barTintColor = kHighlightColor
            navBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: kTextColor]
            navBar.isTranslucent = false
        }
    }
    
    func updateSegControlDesign() {
        //Native segmented control (rendered by iOS 26 as liquid glass). The custom background and
        //divider images that used to fake Android-style underline tabs are no longer applied cleanly
        //by iOS 26 and left hard white lines between the items, so let the system draw the control
        //and only brand the selected segment with the phyphox highlight color.
        let font: [NSAttributedString.Key : Any] = [NSAttributedString.Key.foregroundColor : SettingBundleHelper.getTextColorWhenDarkModeNotSupported() , NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .subheadline)]
        let selectedFont: [NSAttributedString.Key : Any] = [NSAttributedString.Key.foregroundColor : kTextColor, NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .subheadline)]
        segControl!.setTitleTextAttributes(font, for: .normal)
        segControl!.setTitleTextAttributes(selectedFont, for: .selected)
        if #available(iOS 13.0, *) {
            segControl!.selectedSegmentTintColor = UIColor(named: "highlightColor") ?? kHighlightColor
        }
    }
    
    func updateLayout() {
        let offsetTop : CGFloat = self.topLayoutGuide.length
        //The tab strip floats over the content (iOS 26 style, content scrolling behind the glass
        //control), so the pages start right below the navigation bar and get a top content inset
        //instead, keeping their initial content below the tabs. The floating countdown display
        //shares that band; without tabs it needs the inset itself.
        layoutTimerDisplay()
        //Keep the floating tab strip below the bar — the top offset differs per orientation, so the
        //frame set at creation goes stale (in landscape the tabs ended up slightly under the bar)
        tabBar?.frame = CGRect(x: 0, y: offsetTop, width: self.view.frame.width, height: tabBarHeight)
        let timerInset: CGFloat = timerDisplay.map { $0.frame.height + 8 } ?? 0
        let tabInset: CGFloat = (experiment.viewDescriptors!.count > 1) ? tabBarHeight : timerInset
        for vc in experimentViewControllers {
            let oldInset = vc.tableView.contentInset.top
            if oldInset != tabInset {
                let wasAtTop = vc.tableView.contentOffset.y <= -oldInset + 0.5
                vc.tableView.contentInset.top = tabInset
                vc.tableView.verticalScrollIndicatorInsets.top = tabInset
                //Changing the inset does not move the content: a table resting at the old top would
                //keep its top rows behind the tabs (seen on the iPhone 8), so scroll it to the new
                //natural top — but only if the user has not scrolled away
                if wasAtTop {
                    vc.tableView.contentOffset.y = -tabInset
                }
            }
        }
        var offsetBottom: CGFloat = self.bottomLayoutGuide.length
        let offsetFrame: CGRect
        if #available(iOS 11, *) {
            offsetFrame = self.view.safeAreaLayoutGuide.layoutFrame
        } else {
            offsetFrame = self.view.frame
        }
        
        var pageViewControlerRect = CGRect(x: 0, y: offsetTop, width: self.view.frame.width, height: self.view.frame.height-offsetTop)
        
        if let label = self.serverLabel, let labelBackground = self.serverLabelBackground {
            let s = label.sizeThatFits(CGSize(width: offsetFrame.width, height: 300))
            
            let labelBackgroundFrame = CGRect(x: 0, y: self.view.frame.height - s.height - offsetBottom, width: pageViewControlerRect.width, height: s.height + offsetBottom)
            let labelFrame = CGRect(x: offsetFrame.minX, y: self.view.frame.height - s.height - offsetBottom, width: offsetFrame.width, height: s.height)
            label.frame = labelFrame
            labelBackground.frame = labelBackgroundFrame
            label.autoresizingMask = [.flexibleTopMargin, .flexibleWidth]
            labelBackground.autoresizingMask = [.flexibleTopMargin, .flexibleWidth]
            
            offsetBottom += s.height
        }
        
        if self.serverQRIcon != nil {
            NSLayoutConstraint.activate([
                self.serverQRIcon!.trailingAnchor.constraint(equalTo: self.serverLabelBackground!.trailingAnchor, constant: -15.0),
                self.serverQRIcon!.bottomAnchor.constraint(equalTo: self.serverLabel!.bottomAnchor, constant: -20.0 )
            ])
        }
        
        if let bluetoothStatusBar = bluetoothStatusBar {
            let bluetoothStatusBarRect = bluetoothStatusBar.sizeThatFits(self.view.frame.size)
            bluetoothStatusBar.frame = CGRect(x: 0, y: self.view.frame.height - bluetoothStatusBarRect.height - offsetBottom, width: self.view.frame.width, height: bluetoothStatusBarRect.height)
            offsetBottom += bluetoothStatusBarRect.height
        }
        
        pageViewControlerRect = CGRect(origin: pageViewControlerRect.origin, size: CGSize(width: pageViewControlerRect.width, height: pageViewControlerRect.height-offsetBottom))
        
        self.pageViewControler.view.frame = pageViewControlerRect
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.automaticallyAdjustsScrollViewInsets = false
        //Extend under the (opaque) navigation bar and lay out from the top guide instead — with a
        //view that does not underlap the bar, UIKit cannot animate the large-title collapse when
        //this page is pushed from the collection: the still-expanded bar was painted with this
        //page's opaque background for the whole transition and snapped at the end. All own layout
        //already offsets by topLayoutGuide.length on every pass (updateLayout), so the content
        //keeps its position below the bar.
        self.edgesForExtendedLayout = .top
        self.extendedLayoutIncludesOpaqueBars = true
        //The region under the bar is covered by the opaque bar at rest, but shows through during
        //the pop transition while the bar crossfades to the collection's transparent appearance —
        //without a background it appeared black instead of the app background.
        self.view.backgroundColor = UIColor(named: "mainBackground")

        refreshAppTheme()
        
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
        
        updateTimerDisplay()
        
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

            //Give the native control a little air within the strip and size the strip to it.
            segControl!.frame = CGRect(x: 8, y: 4, width: segControl!.frame.width, height: segControl!.frame.height)
            tabBarHeight = segControl!.frame.height + 8

            tabBar = UIScrollView()
            tabBar!.frame = CGRect(x: 0, y: self.topLayoutGuide.length, width: self.view.frame.width, height: tabBarHeight)
            tabBar!.contentSize = CGSize(width: segControl!.frame.width + 16, height: tabBarHeight)
            tabBar!.showsHorizontalScrollIndicator = false
            tabBar!.autoresizingMask = .flexibleWidth
            //No strip background: the glass control floats directly over the content
            tabBar!.backgroundColor = .clear

            //The segmented control's own track is translucent but applies no blur, so its labels mix
            //illegibly with content scrolling behind it. Back it with a capsule of real material —
            //liquid glass on iOS 26, a blur material on earlier versions — like the bar buttons have.
            let backdrop: UIVisualEffectView
            if #available(iOS 26.0, *) {
                backdrop = UIVisualEffectView(effect: UIGlassEffect())
            } else if #available(iOS 13.0, *) {
                backdrop = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
            } else {
                backdrop = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
            }
            backdrop.frame = segControl!.frame
            backdrop.layer.cornerRadius = segControl!.frame.height / 2
            backdrop.clipsToBounds = true
            backdrop.isUserInteractionEnabled = false
            tabBar!.addSubview(backdrop)

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

        //The pages now extend under the floating tab strip and countdown display, so both have to
        //stay above them
        if let tabBar = tabBar {
            self.view.bringSubviewToFront(tabBar)
        }
        if let timerDisplay = timerDisplay {
            self.view.bringSubviewToFront(timerDisplay)
        }
        
        updateSelectedViewCollection()
        
        if(experiment.cameraInput != nil){
            NotificationCenter.default.addObserver(self, selector: #selector(handleCameraError(notification:)), name: .cameraConfigurationFailed, object: nil)
        }
        
    }


    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateSelectedViewCollection()
        refreshAppTheme()
        if (experiment.viewDescriptors!.count > 1) {
            updateSegControlDesign()
        }
        
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
            for bluetoothOutput in experiment.bluetoothOutputs {
                bluetoothOutput.requestSend(triggerId: trigger)
            }
        }
        for (input, output) in viewDescriptor.dataFlow {
            switch input {
            case .buffer(buffer: let buffer, data: _, usedAs: _, keep: _):
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
    
    //Alerts that are not part of a sequenced dialog flow are presented from the top-most view
    //controller, so they stack on an already presented alert (like the denial notice of a
    //permission a custom experiment combines with the flashlight) instead of failing silently.
    private var topMostViewController: UIViewController {
        var top: UIViewController = navigationController ?? self
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    //MARK: - Dialog sequence

    //The dialogs shown when an experiment opens, in order. Each step either presents its dialog
    //and continues with the next step when it is dismissed, or passes through directly, so no
    //dialog collides with (and silently cancels) another one.
    private enum DialogSequence {
        case systemPermissions
        case dataPolicy
        case bluetoothConnections
        case networkConnections
        case photosensitivity
        case saveLocally
        case hints
    }

    private func executeSequence(from step: DialogSequence) {
        switch step {
        case .systemPermissions:
            experiment.willBecomeActive(
                onSuccess: { [weak self] in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.hasCompletedInitialPermissionCheck = true
                        self.executeSequence(from: .dataPolicy)
                    }
                },
                { [weak self] in
                    DispatchQueue.main.async {
                        self?.navigationController?.popToRootViewController(animated: true)
                    }
                }
            )

        case .dataPolicy:
            if let networkConnection = experiment.networkConnections.first {
                let sensorList = experiment.sensorInputs.map { $0.sensorType.getLocalizedName() }
                networkConnection.showDataAndPolicy(infoMicrophone: experiment.audioInputs.count > 0, infoLocation: experiment.gpsInputs.count > 0, infoSensorData: experiment.sensorInputs.count > 0, infoSensorDataList: sensorList, callback: self)
            } else {
                executeSequence(from: .bluetoothConnections)
            }

        case .bluetoothConnections:
            if experiment.bluetoothDevices.count > 0 {
                connectToBluetoothDevices()
            } else {
                executeSequence(from: .networkConnections)
            }

        case .networkConnections:
            if experiment.networkConnections.count > 0 {
                connectToNetworkDevices()
            } else {
                executeSequence(from: .photosensitivity)
            }

        case .photosensitivity:
            //Like on Android, the photosensitivity warning is deliberately shown on every open
            //of an experiment that can strobe the flashlight, rather than offering a permanent
            //dismissal that would silence it forever.
            if !photosensitivityWarningShown, experiment.flashlightOutput?.usesStrobe == true {
                photosensitivityWarningShown = true
                UIAlertController.PhyphoxUIAlertBuilder()
                    .title(title: localize("warning_photosensitivity"))
                    .message(message: localize("warning_photosensitivity_message"))
                    .preferredStyle(style: .alert)
                    .addOkAction(handler: { [weak self] _ in
                        self?.executeSequence(from: .saveLocally)
                    })
                    .show(in: self.topMostViewController, animated: true)
            } else {
                executeSequence(from: .saveLocally)
            }

        case .saveLocally:
            //Ask to save the experiment locally if it has been loaded from a remote source
            if !experiment.local && !ExperimentManager.shared.experimentInCollection(crc32: experiment.crc32) {
                UIAlertController.PhyphoxUIAlertBuilder()
                    .title(title: localize("save_locally"))
                    .message(message: localize("save_locally_message"))
                    .preferredStyle(style: .alert)
                    .addActionWithTitle(localize("save_locally_button"), style: .default, handler: { [weak self] _ in
                        do {
                            try self?.saveLocally()
                        }
                        catch {
                            print(error)
                        }
                        self?.executeSequence(from: .hints)
                    })
                    .addCancelAction(handler: { [weak self] _ in
                        self?.executeSequence(from: .hints)
                    })
                    .show(in: self.navigationController!, animated: true)
            } else {
                executeSequence(from: .hints)
            }

        case .hints:
            presentNextHint()
        }
    }

    private func presentNextHint() {
        let defaults = UserDefaults.standard

        if let playItem = playItem, hintTooltip == nil, !startHintShown {
            startHintShown = true
            let key = "experiment_start_hint_dismiss_count"
            if (defaults.integer(forKey: key) < 3) {
                showHintBubble(text: localize("start_hint"), item: playItem, defaultsKey: key)
                return
            }
        }

        if let actionItem = actionItem, hintTooltip == nil, !infoHintShown && (experiment.localizedCategory != localize("categoryRawSensor")) {
            infoHintShown = true
            let key = "experiment_info_hint_dismiss_count"
            if (defaults.integer(forKey: key) < 3) {
                showHintBubble(text: localize("experimentinfo_hint"), item: actionItem, defaultsKey: key)
                return
            }
        }
    }

    private func showHintBubble(text: String, item: UIBarButtonItem, defaultsKey: String) {
        let tooltip = HintTooltipView(text: text, onDismiss: { [weak self] in
            let defaults = UserDefaults.standard
            defaults.set(defaults.integer(forKey: defaultsKey) + 1, forKey: defaultsKey)
            self?.hintTooltip = nil
            self?.presentNextHint()
        })

        let maxWidth = min(CGFloat(280), view.bounds.width - 24)
        let size = tooltip.fittingSize(maxWidth: maxWidth)

        //Aim the pointer at the real on-screen button. UIBarButtonItem does not expose its view
        //publicly; reading the "view" key via KVC works (and is not flagged as private-API use, as
        //"view" is a common public key). Button positions differ per device, so an estimate can't be
        //right on every phone — fall back to one only if the actual view is unavailable.
        let targetX: CGFloat
        if let itemView = item.value(forKey: "view") as? UIView, itemView.window != nil {
            targetX = view.convert(itemView.bounds, from: itemView).midX
        } else {
            let items = navigationItem.rightBarButtonItems ?? []
            let indexFromRight = CGFloat(items.firstIndex(of: item) ?? 0)
            targetX = view.bounds.maxX - (view.safeAreaInsets.right + 8) - (indexFromRight + 0.5) * 44
        }

        //self.view starts right below the navigation bar (edgesForExtendedLayout is empty), so place
        //the bubble just under the bar pointing up at the buttons. The buttons never move — a tab
        //strip or the countdown label appear below/beside them — so this stays fixed either way, even
        //if the bubble briefly overlays the top of the tab strip.
        var originX = targetX - size.width / 2
        originX = max(12, min(originX, view.bounds.width - 12 - size.width))
        let originY: CGFloat = 8

        tooltip.frame = CGRect(x: originX, y: originY, width: size.width, height: size.height)
        tooltip.pointerX = targetX - originX
        view.addSubview(tooltip)
        hintTooltip = tooltip
    }

    private func dismissHintTooltip() {
        hintTooltip?.dismissTooltip()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if #available(iOS 14.0, *) {
            for vc in experimentViewControllers {
                for view in vc.modules {
                    if let depthGUI = view.view as? ExperimentDepthGUIView {
                        guard let session = experiment.depthInput?.session as? ExperimentDepthInputSession else {
                            continue
                        }
                        session.attachDelegate(delegate: depthGUI)
                        depthGUI.depthGUISelectionDelegate = session
                    }
                    
                    if let cameraGUI = view.view as? ExperimentCameraUIView {
                        guard let session = experiment.cameraInput?.session as? ExperimentCameraInputSession else {
                            continue
                        }
                        cameraGUI.cameraModelOwner = session.attachDelegate(cameraGUI)
                        cameraGUI.cameraTextureProvider = session.cameraModel?.getTextureProvider()

                    }
                    
                }
            }
        }
        if isMovingToParent && !hasCompletedInitialPermissionCheck {
            //First appearance: resolve permissions, then run the full dialog sequence
            executeSequence(from: .systemPermissions)
        } else {
            //Re-appearing, for example after returning from the experiment info: reconnect what
            //viewDidDisappear tore down and let the sequence pass through the remaining steps
            executeSequence(from: .dataPolicy)
        }

        //Launch-argument seam for unattended automation (see AutomationLaunchOptions in
        //AppDelegate): -phyphoxRemote brings the remote server up for this session, exactly as
        //the menu toggle's confirmed action does, so a host script can drive the REST API.
        //Only once - a later manual toggle stays the user's decision.
        if AutomationLaunchOptions.remoteEnabled && !didLaunchWebServerForAutomation {
            didLaunchWebServerForAutomation = true
            launchWebServer()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        //Tear the hint down without advancing the sequence; the view is going away.
        hintTooltip?.removeFromSuperview()
        hintTooltip = nil
    }

    private func installFittingTitle() {
        let titleLabel = FittingTitleLabel()
        titleLabel.text = experiment.displayTitle
        titleLabel.textColor = kTextColor
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.numberOfLines = 2 //Second line always available, see intrinsicContentSize
        //Sizing via Auto Layout with an explicit height: with the default autoresizing-mask
        //constraints the bar assigns the title view a single-line-high frame after rotation
        //(regardless of the intrinsic size), which truncates the wrapped two-line case.
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.heightAnchor.constraint(equalToConstant: FittingTitleLabel.twoLineHeight).isActive = true
        self.navigationItem.titleView = titleLabel
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if #available(iOS 14.0, *) {
            if let session = experiment.depthInput?.session as? ExperimentDepthInputSession {
                session.stopSession()
            }
            
            if let camSession = experiment.cameraInput?.session as? ExperimentCameraInputSession {
                camSession.endSession()
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

    private var didLaunchWebServerForAutomation = false
    
    private func launchWebServer() {
        experiment.setKeepScreenOn(true)
        if !webServer.start() {
            //The translated message must not contain a format placeholder (non-professional
            //translators tend to break template strings), so the port is appended in code.
            UIAlertController.PhyphoxUIAlertBuilder()
                .title(title: localize("remoteServerPortInUseTitle"))
                .message(message: localize("remoteServerPortInUse") + " (Port \(webServer.port))")
                .preferredStyle(style: .alert)
                .addOkAction()
                .show(in: self.navigationController!, animated: true)
            if !experiment.running {
                experiment.setKeepScreenOn(false)
            }
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
                var ip: [String] = []
                var interfaceAdresses: UnsafeMutablePointer<ifaddrs>? = nil
                if getifaddrs(&interfaceAdresses) == 0 {
                    var iPtr = interfaceAdresses
                    while iPtr != nil {
                        defer {iPtr = iPtr?.pointee.ifa_next}
                        
                        let interface = iPtr?.pointee
                        if interface?.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                            if let name = String(validatingUTF8: (interface?.ifa_name)!) {
                                if ["en0", "bridge100"].contains(name) {
                                    var addr = interface?.ifa_addr.pointee
                                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                                    getnameinfo(&addr!, socklen_t((interface?.ifa_addr.pointee.sa_len)!), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                                    ip.append(String(cString: hostname))
                                }
                            }
                        }
                    }
                }
                if ip.count > 0 {
                    for addr in ip {
                        if url != "" {
                            url += "\n"
                        }
                        if webServer.port != 80 {
                            url += "http://\(addr):\(webServer.port)"
                        } else {
                            url += "http://\(addr)"
                        }
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
            
            var image = UIImage(named: "new_experiment_qr")!.resize(size: CGSize(width: 30, height: 30))
            if #available(iOS 13.0, *) {
                let config = UIImage.SymbolConfiguration(
                    pointSize: 25, weight: .medium, scale: .default)
                
                image = UIImage(systemName: "info.circle.fill", withConfiguration: config)!
            } else {
                // Fallback on earlier versions
            }
            
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
        let filename = FileNameFormat.formatFilename(title: experiment.displayTitle, timeReference: experiment.timeReference)
        export.runExport(format, singleSet: singleSet, filename: filename, timeReference: experiment.timeReference) { (errorMessage, fileURL) in
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
            .addTextField(configHandler: { [unowned self] (textField) in
                textField.text = FileNameFormat.format(title: self.experiment.displayTitle, timeReference: self.experiment.timeReference)
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
    
    private func saveTheState(title: String){
        do {
            if !FileManager.default.fileExists(atPath: savedExperimentStatesURL.path) {
                try FileManager.default.createDirectory(atPath: savedExperimentStatesURL.path, withIntermediateDirectories: false, attributes: nil)
            }
            
            //For now, we disable the new state serializer (saving buffers to a separate binary file)
            //until the Android version has caught up and can offer the same function
            //_ = try self.experiment.saveState(to: savedExperimentStatesURL, with: title)
            
            //Instead use the legacy state serializer for now:
            let fileName = FileNameFormat.formatFilename(title: self.experiment.displayTitle, timeReference: self.experiment.timeReference) + ".phyphox"
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
        let fileName = FileNameFormat.formatFilename(title: experiment.displayTitle, timeReference: experiment.timeReference) + ".phyphox"
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
    
    private func updateTimerDisplay() {
        if timerEnabled {
            if timerDisplay == nil {
                createTimerDisplay()
            }
            setTimerLabel(timerDelay)
        } else if let timerDisplay = timerDisplay {
            timerDisplay.removeFromSuperview()
            self.timerDisplay = nil
            self.timerDisplayBackdrop = nil
            self.timerLabel = nil
            tabBar?.contentInset.right = 0
            updateLayout()
        }
    }

    private func createTimerDisplay() {
        let label = UILabel()
        //Monospaced digits keep the capsule from wobbling while the countdown ticks
        label.font = UIFont.monospacedDigitSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .headline).pointSize, weight: .semibold)
        label.textColor = UIColor(named: "textColor")
        label.textAlignment = .center

        //Same material as the floating tab strip: liquid glass on iOS 26, blur before
        let backdrop: UIVisualEffectView
        if #available(iOS 26.0, *) {
            backdrop = UIVisualEffectView(effect: UIGlassEffect())
        } else if #available(iOS 13.0, *) {
            backdrop = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        } else {
            backdrop = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        }
        backdrop.clipsToBounds = true
        backdrop.isUserInteractionEnabled = false

        let container = UIView()
        container.addSubview(backdrop)
        container.addSubview(label)
        self.view.addSubview(container)
        self.view.bringSubviewToFront(container)

        timerDisplay = container
        timerDisplayBackdrop = backdrop
        timerLabel = label
        updateLayout()
    }

    private func layoutTimerDisplay() {
        guard let container = timerDisplay, let label = timerLabel else { return }
        let textSize = label.sizeThatFits(CGSize(width: 200, height: 100))
        let h = textSize.height + 12
        let w = textSize.width + 24
        var safeRight: CGFloat = 0
        if #available(iOS 11, *) {
            safeRight = view.safeAreaInsets.right
        }
        container.frame = CGRect(x: view.bounds.width - safeRight - 8 - w, y: self.topLayoutGuide.length + 4, width: w, height: h)
        timerDisplayBackdrop?.frame = container.bounds
        timerDisplayBackdrop?.layer.cornerRadius = h / 2
        label.frame = container.bounds

        //Pad the tab strip's scrollable range by the capsule overlap, so the last tabs can be
        //scrolled out from under the countdown display and remain reachable
        tabBar?.contentInset.right = view.bounds.width - container.frame.minX + 8
    }

    private func setTimerLabel(_ value: Double) {
        timerLabel?.text = countdownFormatter.string(from: value as NSNumber)
        layoutTimerDisplay()
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
            
            self.updateTimerDisplay()
        }))
        
        alert.addAction(UIAlertAction(title: localize("disableTimedRun"), style: .cancel, handler: { [unowned self] action in
            
            self.timerEnabled = false
            self.timerDelay = Double(timedRunDialogView?.delay.tf.text?.replacingOccurrences(of: ",", with: ".") ?? "0.0") ?? 0.0
            self.timerDuration = Double(timedRunDialogView?.duration.tf.text?.replacingOccurrences(of: ",", with: ".") ?? "0.0") ?? 0.0
            self.timerBeep.countdown = timedRunDialogView?.beeperCountdown.sw.isOn ?? false
            self.timerBeep.start = timedRunDialogView?.beeperStart.sw.isOn ?? false
            self.timerBeep.running = timedRunDialogView?.beeperRunning.sw.isOn ?? false
            self.timerBeep.stop = timedRunDialogView?.beeperStop.sw.isOn ?? false
            
            self.updateTimerDisplay()
        }))
        
        self.navigationController!.present(alert, animated: true, completion: nil)
    }
    
    @objc func action(_ item: UIBarButtonItem) {
        dismissHintTooltip()
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
            
            let tmpFile = (NSTemporaryDirectory() as NSString).appendingPathComponent("\(FileNameFormat.formatFilename(title: self.experiment.displayTitle, timeReference: self.experiment.timeReference)).png")
            
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
    
    func startExperiment() {
        let defaults = UserDefaults.standard
        let key = "experiment_start_hint_dismiss_count"
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
        
        if !experiment.running {
            experiment.setKeepScreenOn(true)
            
            if experimentStartTimer != nil {
                experimentStartTimer!.invalidate()
                experimentStartTimer = nil
                
                updateTimerDisplay()
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

                guard timerLabel != nil else { return }

                setTimerLabel(d)

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

                    setTimerLabel(dt)
                }
                
                after(0.02) {
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

                setTimerLabel(self.timerDelay)
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
        dismissHintTooltip()
        if experiment.running {
            stopExperiment()
        }
        else {
            startExperiment()
        }
    }
    
    @objc func handleCameraError(notification: Notification) {
        DispatchQueue.main.async {

            //If the camera could not be set up because its permission is missing, the
            //permission flow already informs the user with the accurate explanation - the
            //generic loading error would only replace it with a less helpful message.
            guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
                return
            }

            let alert = UIAlertController(title: localize("cameraLoadingErrorTitle"),
                                          message: (notification.userInfo?["message"] as? String ?? localize("cameraLoadingErrorMessage6")) + localize("cameraLoadingErrorSecondMessage"),
                                          preferredStyle: .alert)

            let okAction = UIAlertAction(title: localize("ok"), style: .default) { [weak self] _ in
                if let nav = self?.navigationController {
                    nav.popViewController(animated: true)
                } else {
                    self?.dismiss(animated: true, completion: nil)
                }
            }

            alert.addAction(okAction)
            //Present on top of whatever is currently shown instead of dismissing it: the
            //presented dialog may carry information of its own, like the photosensitivity
            //warning
            self.topMostViewController.present(alert, animated: true, completion: nil)
        }
    }
    
    @objc func clearDataDialog() {
        dismissHintTooltip()

        let clearGroups = experiment.clearGroups

        if clearGroups.isEmpty {
            let al = UIAlertController(title: localize("clear_data"), message: localize("clear_data_question"), preferredStyle: .alert)

            al.addAction(UIAlertAction(title: localize("clear"), style: .default, handler: { [unowned self] action in
                self.clearData(clearGroups: [])
            }))
            al.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler: nil))

            self.navigationController!.present(al, animated: true, completion: nil)
        } else {
            //Like on Android, buffers assigned to a clear group are only cleared if the user
            //explicitly selects that group.
            let selectionView = ClearGroupSelectionView(groups: clearGroups)

            let al = UIAlertController(title: localize("clear_data"), message: localize("clear_data_question_select"), preferredStyle: .alert)
            al.__pt__setAccessoryView(selectionView)

            al.addAction(UIAlertAction(title: localize("clear"), style: .default, handler: { [unowned self] action in
                self.clearData(clearGroups: selectionView.selectedGroups())
            }))
            al.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler: nil))

            self.navigationController!.present(al, animated: true, completion: nil)
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
        alertController.view.heightAnchor.constraint(equalToConstant: 350).isActive = true
        alertController.view.widthAnchor.constraint(equalToConstant: 350).isActive = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.centerXAnchor.constraint(equalTo: alertController.view.centerXAnchor).isActive = true
        imageView.centerYAnchor.constraint(equalTo: alertController.view.centerYAnchor).isActive = true
        
        let closeButton = UIAlertAction(title: localize("cancel"), style: .default, handler: nil)
        alertController.addAction(closeButton)
        
        present(alertController, animated: true, completion: nil)
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

        guard timerLabel != nil else { return }

        setTimerLabel(d)

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

            setTimerLabel(dt)
        }
        
        after(0.02) {
            updateT()
        }
        
        experimentRunTimer = Timer.scheduledTimer(timeInterval: d, target: self, selector: #selector(stopTimerFired), userInfo: nil, repeats: false)
    }
    
    
    func clearData(clearGroups: [String]) {
        self.experiment.timeReference.registerEvent(event: .CLEAR)
        self.experiment.bluetoothDevices.forEach { $0.writeEventCharacteristic(timeMapping: self.experiment.timeReference.timeMappings.last) }

        self.stopExperiment()
        self.experiment.clear(byUser: true, clearGroups: clearGroups)
        
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
                executeSequence(from: .networkConnections)
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

        //No more dialogs shown. Continue with any other dialog that had to wait.
        executeSequence(from: .networkConnections)
    }

    func bluetoothScanDialogDismissed() {
        //Re-enter the bluetooth step: the device picked in the scan dialog still has to be
        //connected before the sequence moves on
        executeSequence(from: .bluetoothConnections)
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
        executeSequence(from: .photosensitivity)
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
        executeSequence(from: .bluetoothConnections)
    }
    
    func refreshAppTheme(){
        if #available(iOS 12.0, *) {
            if(SettingBundleHelper.getAppMode() == Utility.LIGHT_MODE ||
               (SettingBundleHelper.getAppMode() == Utility.SYSTEM_MODE && UIScreen.main.traitCollection.userInterfaceStyle == .light)){
                if #available(iOS 13.0, *) {
                    view.overrideUserInterfaceStyle = .light
                } else {
                    // Fallback on earlier versions
                }
            } else if(SettingBundleHelper.getAppMode() == Utility.DARK_MODE ||
                      (SettingBundleHelper.getAppMode() == Utility.SYSTEM_MODE && UIScreen.main.traitCollection.userInterfaceStyle == .dark)){
                if #available(iOS 13.0, *) {
                    view.overrideUserInterfaceStyle = .dark
                } else {
                    // Fallback on earlier versions
                }
            }
        } else {
            // Fallback on earlier versions
        }
    }
    
    func showUpdatedConnectedDevices(connectedDevices: [ConnectedDevicesDataModel]) {
        if let bluetoothStatusBar = bluetoothStatusBar {
            if (bluetoothStatusBar.updateData(connectedDevices)) {
                self.updateLayout()
            }
        } else {
            let statusBar = ConnectedBluetoothDevicesViewController(frame: CGRect(x: 0, y: self.view.frame.height, width: self.view.frame.width, height: 0), data: connectedDevices)
            self.view.addSubview(statusBar)
            bluetoothStatusBar = statusBar
            self.updateLayout()
        }
    }
    
}

extension ExperimentPageViewController: ExperimentAnalysisDelegate {
    func analysisWillUpdate(_: ExperimentAnalysis) {
        for module in viewModules.flatMap({ $0 }) {
            if let analysisLimitedViewModule = module.view as? AnalysisLimitedViewModule {
                analysisLimitedViewModule.analysisRunning = true
            }
        }
    }
    
    func analysisDidUpdate(_: ExperimentAnalysis) {
        for module in viewModules.flatMap({ $0 }) {
            if let analysisLimitedViewModule = module.view as? AnalysisLimitedViewModule {
                analysisLimitedViewModule.analysisRunning = false
            }
        }
    }
    
    func analysisSkipped(_ analysis: ExperimentAnalysis) {
        for module in viewModules.flatMap({ $0 }) {
            if let analysisLimitedViewModule = module.view as? AnalysisLimitedViewModule {
                analysisLimitedViewModule.analysisRunning = false
            }
        }
    }
}

//Accessory view for the clear-data dialog of an experiment with clear groups: one switch per
//group, all off by default, so protected buffers are only cleared on explicit selection.
final class ClearGroupSelectionView: UIView {
    private let groups: [String]
    private var switches: [UISwitch] = []

    private let rowHeight: CGFloat = 40.0
    private let sideMargin: CGFloat = 24.0

    init(groups: [String]) {
        self.groups = groups
        super.init(frame: .zero)

        for group in groups {
            let groupSwitch = UISwitch()
            groupSwitch.isOn = false
            groupSwitch.onTintColor = UIColor(named: "highlightColor")
            switches.append(groupSwitch)
            addSubview(groupSwitch)

            let label = UILabel()
            label.text = group
            label.font = .systemFont(ofSize: 16)
            label.textColor = UIColor(named: "textColor")
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.5
            label.tag = 1
            addSubview(label)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: CGFloat(groups.count) * rowHeight + 16.0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let labels = subviews.filter { $0.tag == 1 }
        for (i, groupSwitch) in switches.enumerated() {
            let y = 8.0 + CGFloat(i) * rowHeight
            let switchSize = groupSwitch.sizeThatFits(bounds.size)
            groupSwitch.frame = CGRect(x: bounds.width - sideMargin - switchSize.width, y: y + (rowHeight - switchSize.height)/2.0, width: switchSize.width, height: switchSize.height)
            if i < labels.count {
                labels[i].frame = CGRect(x: sideMargin, y: y, width: bounds.width - 2*sideMargin - switchSize.width - 8.0, height: rowHeight)
            }
        }
    }

    func selectedGroups() -> [String] {
        return zip(groups, switches).filter { $0.1.isOn }.map { $0.0 }
    }
}

///Navigation bar title label that adapts to the space the bar items leave: full headline size when
///the title fits, shrunk down to 70% to stay on one line, and wrapped onto a second line for
///titles too long even at that size.
class FittingTitleLabel: UILabel {
    ///Room for two lines at the minimum size — the label's height at all times: a height that
    ///changes with the fitting result does not work, since the bar re-queries the intrinsic size
    ///only unreliably after rotation (verified by logging), leaving a wrapped title in a
    ///single-line-high frame, shown truncated. With the constant height a single-line title is
    ///simply centered vertically — visually identical — and the wrapped case has its second line
    ///available from the start.
    static var twoLineHeight: CGFloat {
        let base = UIFont.preferredFont(forTextStyle: .headline)
        return ceil(2 * base.withSize(base.pointSize * 0.7).lineHeight) + 2
    }

    //Width: ask for all the width the navigation bar has left between its items
    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.layoutFittingExpandedSize.width, height: FittingTitleLabel.twoLineHeight)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fitText()
    }

    //Inputs of the last fitting run: layoutSubviews fires on every bar layout pass (per frame
    //during interactive transitions), so skip the measuring when nothing changed
    private var lastFittedText: String? = nil
    private var lastFittedWidth: CGFloat = 0
    private var lastFittedBaseSize: CGFloat = 0

    private func fitText() {
        guard let text = text, !text.isEmpty, bounds.width > 0 else { return }
        let base = UIFont.preferredFont(forTextStyle: .headline)
        if text == lastFittedText && bounds.width == lastFittedWidth && base.pointSize == lastFittedBaseSize {
            return
        }
        lastFittedText = text
        lastFittedWidth = bounds.width
        lastFittedBaseSize = base.pointSize
        let minSize = base.pointSize * 0.7
        let ns = text as NSString

        //Find the largest size (in 0.5pt steps) at which the whole title measures within a single
        //line. Measured per candidate size rather than scaled linearly: glyph advances do not scale
        //exactly linearly with the point size, and a size estimated slightly too large leaves the
        //title truncated with an ellipsis instead of shown in full.
        var singleLineSize: CGFloat? = nil
        var size = base.pointSize
        while size >= minSize {
            if ns.size(withAttributes: [NSAttributedString.Key.font: base.withSize(size)]).width <= bounds.width {
                singleLineSize = size
                break
            }
            size -= 0.5
        }

        //If no size fits a single line, stay at the minimum size — the text then wraps into the
        //second line, which the constant intrinsic height keeps available at all times
        let targetFont = base.withSize(singleLineSize ?? minSize)
        //Only touch the label when something actually changes to avoid a layout feedback loop
        if font.pointSize != targetFont.pointSize {
            font = targetFont
        }
    }
}
