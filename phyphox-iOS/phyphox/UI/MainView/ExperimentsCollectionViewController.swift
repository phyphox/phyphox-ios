//
//  ExperimentsCollectionViewController.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import UIKit
import CoreBluetooth
import ZipZap

private let minCellWidth: CGFloat = 320.0
private let phyphoxCatHintRelease = "1.1.12" //If this is updated to the current version, the hint bubble for the support menu is shown again
private let hintReleaseKey = "supportHintVersion"

protocol ExperimentController {
    func launchExperimentByURL(_ url: URL, chosenPeripheral: CBPeripheral?) -> Bool
    func addExperimentsToCollection(_ list: [Experiment])
    func loadExperimentFromPeripheral(_ peripheral: CBPeripheral)
}

final class ExperimentsCollectionViewController: CollectionViewController, ExperimentController, DeviceIsChosenDelegate, UIPopoverPresentationControllerDelegate {
    
    private let willBeFirstViewForUser: Bool //Set to false if phyphox is launched with a specific experiment URL. In this case, the ExperimentCollectionViewController will be instantiated, but it will be asked to launch that experiment right away before the user has a chance to interact with the experiment list. So, any dialogs corresponding to the experiment list (like the do-not-risk-your-phone dialog) should be suppressed if the user will not stop at that list
    
    private var cellsPerRow: Int = 1
    private var infoButton: UIButton? = nil
    private var addButton: UIBarButtonItem? = nil
    
    private var hintBubble: HintBubbleViewController? = nil
    
    private var collections: [ExperimentCollection] = []

    override class var viewClass: CollectionContainerView.Type {
        return MainView.self
    }
    
    override class var customCells: [String : UICollectionViewCell.Type]? {
        return ["ExperimentCell" : ExperimentCell.self]
    }
    
    override class var customHeaders: [String : UICollectionReusableView.Type]? {
        return ["Header" : ExperimentHeaderView.self]
    }
    
    func setupNavbar() {
        guard let navBar = self.navigationController?.navigationBar else {
            return
        }
        if #available(iOS 13, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = kBackgroundColor
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: kTextColor]
            navBar.standardAppearance = appearance;
            navBar.scrollEdgeAppearance = navBar.standardAppearance
        } else {
            navBar.barTintColor = kBackgroundColor
            navBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: kTextColor]
            navBar.isTranslucent = true
        }
    }
    
    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        setupNavbar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupNavbar()
        
        let defaults = UserDefaults.standard
        if (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) == phyphoxCatHintRelease && defaults.string(forKey: hintReleaseKey) != phyphoxCatHintRelease {
            hintBubble = HintBubbleViewController(text: localize("categoryPhyphoxOrgHint"), maxWidth: Int(self.navigationController!.view.frame.width * 0.8), onDismiss: {() -> Void in
            })
            guard let hintBubble = hintBubble else {
                return
            }
            hintBubble.popoverPresentationController?.delegate = self
            hintBubble.popoverPresentationController?.sourceView = self.navigationController!.view
            hintBubble.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: self.navigationController!.view.frame.midX, y: self.navigationController!.view.frame.maxY), size: CGSize(width: 1, height: 1))
            
            navigationController!.present(hintBubble, animated: true, completion: nil)
        }
    }
    
    @objc func showHelpMenu(_ item: UIBarButtonItem) {
    
        UIAlertController.PhyphoxUIAlertBuilder()
            .title(title: localize("help"))
            .message(message: nil)
            .preferredStyle(style: .actionSheet)
            .addActionWithTitle(localize("credits"), style: .default, handler: infoPressed)
            .addActionWithTitle(localize("experimentsPhyphoxOrg"), style: .default, handler: { _ in
                UIApplication.shared.open(URL(string: localize("experimentsPhyphoxOrgURL"))!)
            })
            .addActionWithTitle(localize("faqPhyphoxOrg"), style: .default, handler:{ _ in
                UIApplication.shared.open(URL(string: localize("faqPhyphoxOrgURL"))!)
            })
            .addActionWithTitle(localize("remotePhyphoxOrg"), style: .default, handler: { _ in
                UIApplication.shared.open(URL(string: localize("remotePhyphoxOrgURL"))!)
            })
            .addActionWithTitle(localize("settings"), style: .default, handler: { _ in
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }
                UIApplication.shared.open(settingsUrl)
            })
            .addActionWithTitle(localize("deviceInfo"), style: .default, handler: { _ in
                
                let msg =  self.buildDeviceInfoMessage()
                
                UIAlertController.PhyphoxUIAlertBuilder()
                    .title(title: localize("deviceInfo"))
                    .message(message: msg)
                    .preferredStyle(style: .alert)
                    .addActionWithTitle(localize("copyToClipboard"), style: .default, handler: { _ in
                        UIPasteboard.general.string = msg
                        self.dismiss(animated: true, completion: nil)
                    })
                    .addCancelAction()
                    .show(in: self.navigationController!, animated: true, completion: nil)
                
            })
            .sourceView(popoverSourceView: infoButton)
            .sourceRect(popoverSourceRect: infoButton!.frame)
            .addCancelAction()
            .show(in: self, animated: true)
        
         
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "phyphox"
        
        reload()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: NSNotification.Name(rawValue: ExperimentsReloadedNotification), object: nil)
      
        ExperimentManager.shared.reloadUserExperiments()

        infoButton = UIButton(type: .infoDark)
        infoButton!.addTarget(self, action: #selector(showHelpMenu(_:)), for: .touchUpInside)
        infoButton!.sizeToFit()
        
        addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addExperiment))
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: infoButton!)
        navigationItem.rightBarButtonItem = addButton!
        
        let defaults = UserDefaults.standard
        let key = "donotshowagain"
        if (willBeFirstViewForUser && !defaults.bool(forKey: key)) {
            UIAlertController.PhyphoxUIAlertBuilder()
                .title(title: localize("warning"))
                .message(message: localize("damageWarning"))
                .preferredStyle(style: .alert)
                .addActionWithTitle(localize("donotshowagain"), style: .default, handler: { _ in
                    defaults.set(true, forKey: key)
                })
                .addCancelAction()
                .show(in: navigationController!, animated: true)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        hintBubble?.closeHint()
        hintBubble = nil
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        hintBubble?.closeHint()
        hintBubble = nil
    }
    
    //Force iPad-style popups (for the hint to the menu)
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if (indexPath.section == collections.count - 1 ) {
            UserDefaults.standard.set(phyphoxCatHintRelease, forKey: hintReleaseKey)
        }
    }
    
    private func showOpenSourceLicenses() {
        UIAlertController.PhyphoxUIAlertBuilder()
            .title(title: "Open Source Licenses")
            .message(message: PTFile.stringWithContentsOfFile(Bundle.main.path(forResource: "Licenses", ofType: "ptf")!))
            .preferredStyle(style: .alert)
            .addCloseAction()
            .show(in: navigationController!, animated: true, completion: nil)
    }

    var bluetoothScanResultsTableViewController: BluetoothScanResultsTableViewController? = nil
    
    private func scanForBLEDevices() {
        
        let infoAction = UIAlertAction(title: localize("bt_more_info_link_button"), style: .default) { (action) in
            UIApplication.shared.open(URL(string: localize("bt_more_info_link_url"))!)
        }
        
        let cancelAction = UIAlertAction(title: localize("cancel"), style: .cancel) { (action) in }
        
        bluetoothScanResultsTableViewController = BluetoothScanResultsTableViewController(filterByName: nil, filterByUUID: nil, checkExperiments: true, autoConnect: false)
        bluetoothScanResultsTableViewController?.tableView = FixedTableView()
        bluetoothScanResultsTableViewController?.deviceIsChosenDelegate = self
        
        
        UIAlertController.PhyphoxUIAlertBuilder()
            .title(title: localize("bt_pick_device"))
            .message(message: localize("bt_scanning_generic") + "\n\n" + localize("bt_more_info_link_text"))
            .preferredStyle(style:  UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad ? .alert : .actionSheet)
            .setAlertDialogHeight(height: 550)
            .addDefinedAction(action: infoAction)
            .addDefinedAction(action: cancelAction)
            .sourceView(popoverSourceView: self.view)
            .sourceRect(popoverSourceRect: CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0))
            .permittedArrowDir(popoverPermittedArrowDir: [])
            .setAlertValue(value: bluetoothScanResultsTableViewController, key: "contentViewController")
            .show(in: navigationController!, animated: true)
        

    }
    
    func useChosenBLEDevice(chosenDevice: CBPeripheral, advertisedUUIDs: [CBUUID]?) {
        let experimentCollections = ExperimentManager.shared.getExperimentsForBluetoothDevice(deviceName: chosenDevice.name, deviceUUIDs: advertisedUUIDs)
        
        var files: [URL] = []
        for collection in experimentCollections {
            for (experiment, _) in collection.experiments {
                if let file = experiment.source {
                    files.append(file)
                }
            }
        }
        
        
        let experimentOnDevice: Bool
        if let advertisedUUIDs = advertisedUUIDs {
            experimentOnDevice = advertisedUUIDs.map({(uuid) -> String in uuid.uuid128String}).contains(phyphoxServiceUUID.uuidString)
        } else {
            experimentOnDevice = false
        }
        
        if files.count > 0 {
            let dialog = ExperimentPickerDialogView(title: localize("open_bluetooth_assets_title"), message: localize("open_bluetooth_assets") + (experimentOnDevice ? "\n\n" +  localize("newExperimentBluetoothLoadFromDeviceInfo") : ""), experiments: files, delegate: self, chosenPeripheral: chosenDevice, onDevice: experimentOnDevice)
            dialog.show(animated: true)
        } else {
            loadExperimentFromPeripheral(chosenDevice)
        }
    }
    
    func loadExperimentFromPeripheral(_ peripheral: CBPeripheral) {
        bluetoothScanResultsTableViewController?.ble.loadExperimentFromPeripheral(peripheral, viewController: self, experimentLauncher: self)
    }

    func infoPressed(_ action: UIAlertAction) {
        let vc = UIViewController()
        vc.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        vc.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
        
        let v = CreditsView()
        v.onCloseCallback = {
            vc.dismiss(animated: true, completion: nil)
        }
        v.onLicenceCallback = {
            vc.dismiss(animated: true, completion: nil)
            self.showOpenSourceLicenses()
        }
        vc.view = v
        
        navigationController!.present(vc, animated: true, completion: nil)
    }

    @objc func reload() {
        collections = ExperimentManager.shared.experimentCollections
        selfView.collectionView.reloadData()
    }
    
    init(willBeFirstViewForUser: Bool) {
        self.willBeFirstViewForUser = willBeFirstViewForUser
        super.init()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    let overlayTransitioningDelegate = CreateViewControllerTransitioningDelegate()
    
    @objc func addExperiment() {
        var menuElements: [MenuTableViewController.MenuElement] = []
        
        menuElements.append(getAdustedQRCodeIconAsAppMode())
        
        menuElements.append(MenuTableViewController.MenuElement(label: localize("newExperimentBluetooth"), icon: UIImage(named: "new_experiment_bluetooth")!, callback: scanForBLEDevices))
        menuElements.append(MenuTableViewController.MenuElement(label: localize("newExperimentSimple"), icon: UIImage(named: "new_experiment_simple")!, callback: createSimpleExperiment))
        
        if let menu = MenuTableViewController(label: localize("newExperiment"), message: nil, elements: menuElements).getMenu(sourceButton: addButton!) {
            present(menu, animated: true, completion: nil)
        }
    }

    func launchScanner() {
        let vc = ScannerViewController()
        vc.experimentLauncher = self
        let nav = UINavigationController(rootViewController: vc)
        
        if iPad {
            nav.modalPresentationStyle = .formSheet
        }
        else {
            nav.transitioningDelegate = overlayTransitioningDelegate
            nav.modalPresentationStyle = .custom
        }
        
        navigationController!.parent!.present(nav, animated: true, completion: nil)
    }

    
    func createSimpleExperiment() {
        let vc = CreateExperimentViewController()
        let nav = UINavigationController(rootViewController: vc)
        vc.onExperimentCreated = {(path) -> () in
            nav.dismiss(animated: true)
            _ = self.launchExperimentByURL(URL(fileURLWithPath: path), chosenPeripheral: nil)
        }
        
        if iPad {
            nav.modalPresentationStyle = .formSheet
        }
        else {
            nav.transitioningDelegate = overlayTransitioningDelegate
            nav.modalPresentationStyle = .custom
        }
        
        navigationController!.parent!.present(nav, animated: true, completion: nil)
    }
    
    //MARK: - UICollectionViewDataSource
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return collections.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return collections[section].experiments.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        var cells: CGFloat = 1.0
        
        let availableWidth = self.view.frame.size.width - collectionView.contentInset.left - collectionView.contentInset.right
        var width = availableWidth
        
        while availableWidth/(cells+1.0) >= minCellWidth {
            cells += 1.0
            width = availableWidth/cells
        }
        
        cellsPerRow = Int(cells)
        
        let h = ceil(UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline).lineHeight + UIFont.preferredFont(forTextStyle: UIFont.TextStyle.caption1).lineHeight + 12)
        
        return CGSize(width: width, height: h)
    }
    
    private func showStateTitleEditForExperiment(_ experiment: Experiment, button: UIButton, oldTitle: String) {
        
        let alertBuilder = UIAlertController.PhyphoxUIAlertBuilder()
        alertBuilder.title(title: localize("rename"))
            .message(message: "")
            .preferredStyle(style: .alert)
            .addTextField(configHandler: {(textfield: UITextField!) -> Void in
                textfield.placeholder = localize("newExperimentInputTitle")
                textfield.text = oldTitle
            })
            .addActionWithTitle(localize("rename"), style: .default, handler: { [unowned self] action in
                do {
                    let textField = alertBuilder.getTextFieldValue()
                
                    if let newTitle = textField.text, newTitle.replacingOccurrences(of: " ", with: "") != "" {
                        try ExperimentManager.shared.renameExperiment(experiment, newTitle: newTitle)
                    }
                }
                catch let error as NSError {
                    let hud = JGProgressHUD(style: .dark)
                    hud.interactionType = .blockTouchesOnHUDView
                    hud.indicatorView = JGProgressHUDErrorIndicatorView()
                    hud.textLabel.text = "Failed to rename experiment: \(error.localizedDescription)"
                    
                    hud.show(in: self.view)
                    
                    hud.dismiss(afterDelay: 3.0)
                }
            })
            .addCancelAction()
            .sourceView(popoverSourceView: self.navigationController!.view)
            .sourceRect(popoverSourceRect: button.convert(button.bounds, to: self.navigationController!.view))
            .show(in: self, animated: true)
        
    }
    
    private func showDeleteConfirmationForExperiment(_ experiment: Experiment, button: UIButton) {
        
        UIAlertController.PhyphoxUIAlertBuilder()
            .title(title: localize("confirmDeleteTitle"))
            .message(message: localize("confirmDelete"))
            .preferredStyle(style: .actionSheet)
            .addActionWithTitle(localize("delete") + " " + experiment.displayTitle, style: .destructive, handler: { [unowned self] action in
                do {
                    try ExperimentManager.shared.deleteExperiment(experiment)
                }
                catch let error as NSError {
                    let hud = JGProgressHUD(style: .dark)
                    hud.interactionType = .blockTouchesOnHUDView
                    hud.indicatorView = JGProgressHUDErrorIndicatorView()
                    hud.textLabel.text = "Failed to delete experiment: \(error.localizedDescription)"
                    
                    hud.show(in: self.view)
                    
                    hud.dismiss(afterDelay: 3.0)
                }
                })
            .addCancelAction()
            .sourceView(popoverSourceView: self.navigationController!.view)
            .sourceRect(popoverSourceRect:  button.convert(button.bounds, to: self.navigationController!.view))
            .show(in: self, animated: true, completion: nil)
                
    }
    
    private func showOptionsForExperiment(_ experiment: Experiment, button: UIButton) {
        
        var isExpSourceNull = false
        if experiment.source != nil {
            isExpSourceNull = false
        } else {
            isExpSourceNull = true
        }
        
        var isStateTitleNull = false
        if experiment.stateTitle != nil {
            isStateTitleNull = false
        } else {
            isStateTitleNull = true
        }
        
        var saveStateAlert = UIAlertAction(title: localize("save_state_share"), style: .default, handler: { [unowned self] action in
            let vc = UIActivityViewController(activityItems: [experiment.source!], applicationActivities: nil)
            vc.popoverPresentationController?.sourceView = self.navigationController!.view
            vc.popoverPresentationController?.sourceRect = button.convert(button.bounds, to: self.navigationController!.view)
            self.navigationController!.present(vc, animated: true)
        })
        
        var renameAlert = UIAlertAction(title: localize("rename"), style: .default, handler: { [unowned self] action in
            self.showStateTitleEditForExperiment(experiment, button: button, oldTitle: experiment.stateTitle!)
        })
        
        UIAlertController.PhyphoxUIAlertBuilder()
            .title(title: "")
            .message(message: "")
            .preferredStyle(style: .actionSheet)
            .addAlertWithCondition(isValueNull: isExpSourceNull, action: saveStateAlert)
            .addAlertWithCondition(isValueNull: isStateTitleNull, action: renameAlert)
            .addDeleteAction(handler: { [unowned self] action in
                self.showDeleteConfirmationForExperiment(experiment, button: button)
            })
            .addCancelAction()
            .sourceView(popoverSourceView: self.navigationController!.view)
            .sourceRect(popoverSourceRect: button.convert(button.bounds, to: self.navigationController!.view))
            .show(in: self)
        
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ExperimentCell", for: indexPath) as! ExperimentCell
        
        let collection = collections[indexPath.section]
        let experiment = collection.experiments[indexPath.row]
        
        cell.experiment = experiment.experiment
        
        if experiment.custom {
            cell.showsOptionsButton = true
            let exp = experiment.experiment
            cell.optionsButtonCallback = { [unowned exp, unowned self] button in
                self.showOptionsForExperiment(exp, button: button)
            }
        }
        else {
            cell.showsOptionsButton = false
            cell.optionsButtonCallback = nil
        }
        
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        let availableWidth = self.view.frame.size.width - collectionView.contentInset.left - collectionView.contentInset.right
        return CGSize(width: availableWidth, height: 36.0)
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath) as! ExperimentHeaderView

            let collection = collections[indexPath.section]

            if collection.type == .phyphoxOrg {
                view.title = localize("categoryPhyphoxOrg")
            } else {
                view.title = collection.title
            }
            var colorsInCollection = [UIColor : Int]()
            for experiment in collection.experiments {
                if let count = colorsInCollection[experiment.experiment.color] {
                    colorsInCollection[experiment.experiment.color] = count + 1
                } else {
                    colorsInCollection[experiment.experiment.color] = 1
                }
            }
            var max = 0
            var catColor = kHighlightColor
            for (color, count) in colorsInCollection {
                if count > max {
                    max = count
                    catColor = color                }
            }
            view.color = catColor
            view.fontColor = catColor.overlayTextColor()
            
            if(collection.type == .phyphoxOrg){
                view.color = kFullWhiteColor.autoLightColor()
                view.fontColor = kFullWhiteColor.autoLightColor().overlayTextColor()
            }

            return view
        }

        fatalError("Invalid supplementary view: \(kind)")
    }
    
    //MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let experiment = collections[indexPath.section].experiments[indexPath.row]

        if experiment.experiment.invalid {
            UIAlertController.PhyphoxUIAlertBuilder()
                .title(title: localize("warning"))
                .message(message: experiment.experiment.localizedDescription)
                .preferredStyle(style: .alert)
                .addOkAction()
                .show(in: self, animated: true)
    
            return
            
        } else if experiment.experiment.appleBan {
            
            /* Apple does not want us to reveal to the user that the experiment has been deactivated by their request. So we may not even show an info button...
             controller.addAction(UIAlertAction(title: localize("appleBanWarningMoreInfo"), style: .default, handler:{ _ in
             UIApplication.shared.openURL(URL(string: localize("appleBanWarningMoreInfoURL"))!)
             }))
             */
            
            UIAlertController.PhyphoxUIAlertBuilder()
                .title(title: localize("warning"))
                .message(message: localize("apple_ban"))
                .preferredStyle(style: .alert)
                .addOkAction()
                .show(in: self, animated: true)
            
            return
            
        } else if experiment.experiment.isLink {
            guard let url = experiment.experiment.localizedLinks.first?.url else {
                
                UIAlertController.PhyphoxUIAlertBuilder()
                    .title(title: localize("url_invalid"))
                    .message(message: localize("url_invalid_msg"))
                    .preferredStyle(style: .alert)
                    .addOkAction()
                    .show(in: self, animated: true)
                
                return
            }
            UIApplication.shared.open(url)
            return
        }
        
        for sensor in experiment.experiment.sensorInputs {
            do {
                if !sensor.ignoreUnavailable {
                    try sensor.verifySensorAvailibility()
                }
            }
            catch SensorError.sensorUnavailable(let type) {
                
                let state = experiment.experiment.stateTitle ?? ""
                let title = experiment.experiment.localizedTitle + (state != "" ? "\n\n" + state : "\n")
                let message = localize("sensorNotAvailableWarningText1") + " \(type.getLocalizedName()) " + localize("sensorNotAvailableWarningText2") + "\n\n" +  (experiment.experiment.localizedDescription ?? "")
                
                showSensorNotAvailableDialogWithExperimentDetails(title, message, experiment.experiment.localizedLinks)
            
                return
            }
            catch {}
        }
        
        if let depthInput = experiment.experiment.depthInput {
            do {
                try ExperimentDepthInput.verifySensorAvailibility(cameraOrientation: nil)
            }
            catch DepthInputError.sensorUnavailable {
                let state = experiment.experiment.stateTitle ?? ""
                let title = experiment.experiment.localizedTitle + (state != "" ? "\n\n" + state : "\n")
                let message =  localize("sensorNotAvailableWarningText1") + localize("sensorDepth") + localize("sensorNotAvailableWarningText2") + "\n\n" +  (experiment.experiment.localizedDescription ?? "")
                
                showSensorNotAvailableDialogWithExperimentDetails(title, message, experiment.experiment.localizedLinks)
         
                return
            }
            catch {}
        }

        let vc = ExperimentPageViewController(experiment: experiment.experiment)

        navigationController?.pushViewController(vc, animated: true)
    }
    
    func showSensorNotAvailableDialogWithExperimentDetails(_ title: String, _ message: String, _ links: [ExperimentLink]){
        let al = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        for link in links {
            al.addAction(UIAlertAction(title: localize(link.label), style: .default, handler: { _ in
                UIApplication.shared.open(link.url)
            }))
        }
        al.addAction(UIAlertAction(title: localize("sensorNotAvailableWarningMoreInfo"), style: .default, handler: { _ in
            UIApplication.shared.open(URL(string: localize("sensorNotAvailableWarningMoreInfoURL"))!)
        }))
         
        al.addAction(UIAlertAction(title: localize("close"), style: .cancel, handler: nil))
        
        self.navigationController!.present(al, animated: true, completion: nil)
    }
    
    enum FileType {
        case unknown
        case phyphox
        case zip
        case partialZip
    }
    
    func detectFileType(data: Data) -> FileType {
        if data.count < 20 {
            return .unknown
        }
        if data[0] == 0x50 && data[1] == 0x4b && data[2] == 0x03 && data[3] == 0x04 {
            //Look for ZIP signature
            return .zip
        }
        let i = data.count - 16 //Offset of possible data descriptor
        if data[i] == 0x50 && data[i+1] == 0x4b && data[i+2] == 0x07 && data[i+3] == 0x08 {
            //Look for data descriptor of a partial ZIP file
            return .partialZip
        }
        if data.range(of: "<phyphox".data(using: .utf8)!) != nil {
            //Naive method to roughly check if this is a phyphox file without actually parsing it.
            //A false positive will be caught be the parser, but we do not want to parse anything that is obviously not a phyphox file.
            return .phyphox
        }
        return .unknown
    }
    
    func handleZipFile(_ url: URL, chosenPeripheral: CBPeripheral?) throws {
        let tmp = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("temp")
        try? FileManager.default.removeItem(at: tmp)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: false, attributes: nil)
        
        let archive = try ZZArchive(url: url)
        var files: [URL] = []
        for entry in archive.entries {
            if (entry.fileMode & S_IFDIR) > 0 {
                continue
            }
            let fileName = tmp.appendingPathComponent(entry.fileName)
            if entry.fileName.hasSuffix(".phyphox") {
                try FileManager.default.createDirectory(at: fileName.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                try entry.newData().write(to: fileName, options: .atomic)
                files.append(fileName)
            } else if fileName.deletingLastPathComponent().lastPathComponent == "res" {
                try FileManager.default.createDirectory(at: fileName.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                try entry.newData().write(to: fileName, options: .atomic)
            }
        }
        
        guard files.count > 0 else {
            throw SerializationError.genericError(message: "No phyphox file found in zip archive.")
        }
        
        if files.count == 1 {
            _ = launchExperimentByURL(files.first!, chosenPeripheral: chosenPeripheral)
        } else {
            var experiments: [URL] = []
            for file in files {
                experiments.append(file)
            }
            
            let dialog = ExperimentPickerDialogView(title: localize("open_zip_title"), message: localize("open_zip_dialog_instructions"), experiments: files, delegate: self, chosenPeripheral: chosenPeripheral, onDevice: false)
            dialog.show(animated: true)
        }
    }
    
    func handlePartialZipFile(_ url: URL, chosenPeripheral: CBPeripheral?) throws {
        let tmp = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("temp.phyphox")
        
        var data = Data()
        
        //Local file header
        data.append(Data([0x50, 0x4b, 0x03, 0x04])) //Local file header signature
        data.append(Data([0x0a, 0x00])) //Version
        data.append(Data([0x08, 0x00])) //General purpose flag
        data.append(Data([0x00, 0x00])) //Compression method
        data.append(Data([0x00, 0x00])) //modification time
        data.append(Data([0x00, 0x00])) //modification date
        data.append(Data([0x00, 0x00, 0x00, 0x00])) //CRC32
        data.append(Data([0x00, 0x00, 0x00, 0x00])) //Compressed size
        data.append(Data([0x00, 0x00, 0x00, 0x00])) //Uncompressed size
        data.append(Data([0x09, 0x00])) //File name length
        data.append(Data([0x00, 0x00])) //Extra field length
        data.append("a.phyphox".data(using: .utf8)!) //File name
        
        //Data (including data descriptor)
        data.append(try Data(contentsOf: url))
        
        let i = data.count - 16 //Offset of possible data descriptor
        let crc32 = data.subdata(in: (i+4..<i+8))
        let compressedSize = data.subdata(in: (i+8..<i+12))
        let uncompressedSize = data.subdata(in: (i+12..<i+16))
        
        //Central directory
        var startIndex = UInt32(data.count)
        data.append(Data([0x50, 0x4b, 0x01, 0x02])) //signature
        data.append(Data([0x0a, 0x00])) //Version made by
        data.append(Data([0x0a, 0x00])) //Version needed
        data.append(Data([0x08, 0x00])) //General purpose flag
        data.append(Data([0x00, 0x00])) //Compression method
        data.append(Data([0x00, 0x00])) //modification time
        data.append(Data([0x00, 0x00])) //modification date
        data.append(crc32) //CRC32
        data.append(compressedSize) //Compressed size
        data.append(uncompressedSize) //Uncompressed size
        data.append(Data([0x09, 0x00])) //File name length
        data.append(Data([0x00, 0x00])) //Extra field length
        data.append(Data([0x00, 0x00])) //File comment length
        data.append(Data([0x00, 0x00])) //Disk number
        data.append(Data([0x00, 0x00])) //Internal file attributes
        data.append(Data([0x00, 0x00, 0x00, 0x00])) //External file attributes
        data.append(Data([0x00, 0x00, 0x00, 0x00])) //Relative offset of local header
        data.append("a.phyphox".data(using: .utf8)!) //File name
        
        //End of central directory
        data.append(Data([0x50, 0x4b, 0x05, 0x06])) //signature
        data.append(Data([0x00, 0x00])) //Disk number
        data.append(Data([0x00, 0x00])) //Start disk number
        data.append(Data([0x01, 0x00])) //Number of central directories on disk
        data.append(Data([0x01, 0x00])) //Number of central directories in total
        data.append(Data([0x37, 0x00, 0x00, 0x00])) //Size of central directory
        data.append(Data(bytes: &startIndex, count: MemoryLayout.size(ofValue: startIndex))) //Start of central directory
        data.append(Data([0x00, 0x00])) //Comment length
        
        
        try data.write(to: tmp, options: .atomic)
        try handleZipFile(tmp, chosenPeripheral: chosenPeripheral)
    }
    
    func launchExperimentByURL(_ url: URL, chosenPeripheral: CBPeripheral?) -> Bool {

        var fileType = FileType.unknown
        var experiment: Experiment?
        var finalURL = url
        
        var experimentLoadingError: Error?
        
        let tmp = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("temp.phyphox")
        
        _ = url.startAccessingSecurityScopedResource()
        
        //TODO: Replace all instances of Data(contentsOf:...) with non-blocking requests
        if url.scheme == "phyphox" {
            //phyphox:// allow to retreive the experiment via https or http. Try both.
            if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                components.scheme = "https"
                do {
                    let data = try Data(contentsOf: components.url!)
                    fileType = detectFileType(data: data)
                    if fileType == .phyphox || fileType == .zip {
                        try data.write(to: tmp, options: .atomic)
                        finalURL = tmp
                    }
                } catch {
                }
                if fileType == .unknown {
                    components.scheme = "http"
                    do {
                        let data = try Data(contentsOf: components.url!)
                        fileType = detectFileType(data: data)
                        if fileType == .phyphox || fileType == .zip {
                            try data.write(to: tmp, options: .atomic)
                            finalURL = tmp
                        }
                    } catch let error {
                        experimentLoadingError = error
                    }
                }
            }
            else {
                experimentLoadingError = SerializationError.invalidFilePath
            }
        }
        else if url.scheme == "http" || url.scheme == "https" {
            //Specific http or https. We need to download it first as InputStream/XMLParser only handles URLs to local files properly. (See todo above)
            do {
                let data = try Data(contentsOf: url)
                fileType = detectFileType(data: data)
                if fileType == .phyphox || fileType == .zip {
                    try data.write(to: tmp, options: .atomic)
                    finalURL = tmp
                }
            } catch let error {
                experimentLoadingError = error
            }
        } else if url.isFileURL {
            //Local file
            do {
                let data = try Data(contentsOf: url)
                fileType = detectFileType(data: data)
                if fileType == .phyphox || fileType == .zip {
                    if (url.absoluteString.starts(with: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].absoluteString)) {
                        finalURL = url
                    } else {
                        try data.write(to: tmp, options: .atomic)
                        finalURL = tmp
                    }
                }
            }
            catch let error {
                experimentLoadingError = error
            }
        } else {
            experimentLoadingError = SerializationError.invalidFilePath
        }
        
        if experimentLoadingError == nil {
            switch fileType {
            case .phyphox:
                    do {
                        experiment = try ExperimentSerialization.readExperimentFromURL(finalURL)
                    } catch let error {
                        experimentLoadingError = error
                    }
            case .zip:
                do {
                    try handleZipFile(finalURL, chosenPeripheral: chosenPeripheral)
                    return true
                } catch let error {
                    experimentLoadingError = error
                }
            case .partialZip:
                do {
                    try handlePartialZipFile(finalURL, chosenPeripheral: chosenPeripheral)
                    return true
                } catch let error {
                    experimentLoadingError = error
                }
            case .unknown:
                experimentLoadingError = SerializationError.invalidExperimentFile(message: "Unkown file format.")
            }
        }
        
        url.stopAccessingSecurityScopedResource()
        
        if experimentLoadingError != nil {
            let message: String
            if let sError = experimentLoadingError as? SerializationError {
                switch sError {
                case .emptyData:
                    message = "Empty data."
                case .genericError(let emessage):
                    message = emessage
                case .invalidExperimentFile(let emessage):
                    message = "Invalid experiment file. \(emessage)"
                case .invalidFilePath:
                    message = "Invalid file path"
                case .newExperimentFileVersion(let phyphoxFormat, let fileFormat):
                    message = "New phyphox file format \(fileFormat) found. Your phyphox version supports up to \(phyphoxFormat) and might be outdated."
                case .writeFailed:
                    message = "Write failed."
                }
            } else {
                message = String(describing: experimentLoadingError!)
            }
            
            
            UIAlertController.PhyphoxUIAlertBuilder()
                .title(title: localize("exp_error"))
                .message(message: "Could not load experiment: \(message)")
                .preferredStyle(style: .alert)
                .addOkAction()
                .show(in: (navigationController)!, animated: true)
            
            return false
        }
        
        guard let loadedExperiment = experiment else { return false }
        
        if loadedExperiment.appleBan {
            /* Apple does not want us to reveal to the user that the experiment has been deactivated by their request. So we may not even show an info button...
             controller.addAction(UIAlertAction(title: localize("appleBanWarningMoreInfo"), style: .default, handler:{ _ in
             UIApplication.shared.openURL(URL(string: localize("appleBanWarningMoreInfoURL"))!)
             }))
             */
            
            UIAlertController.PhyphoxUIAlertBuilder()
                .title(title: localize("warning"))
                .message(message: localize("apple_ban"))
                .preferredStyle(style: .alert)
                .addOkAction()
                .show(in: self, animated: true)
            
            return false
        }
        
        for sensor in loadedExperiment.sensorInputs {
            do {
                if !sensor.ignoreUnavailable {
                    try sensor.verifySensorAvailibility()
                }
            }
            catch SensorError.sensorUnavailable(let type) {
                let state = loadedExperiment.stateTitle ?? ""
                let title = loadedExperiment.localizedTitle + (state != "" ? "\n\n" + state : "\n")
                let message = localize("sensorNotAvailableWarningText1") + " \(type.getLocalizedName()) " + localize("sensorNotAvailableWarningText2") + "\n\n" +  (loadedExperiment.localizedDescription ?? "")
                
                showSensorNotAvailableDialogWithExperimentDetails(title, message, loadedExperiment.localizedLinks)
           
                return false
            }
            catch {}
        }
        
        if let depthInput = loadedExperiment.depthInput {
            do {
                try ExperimentDepthInput.verifySensorAvailibility(cameraOrientation: nil)
            }
            catch DepthInputError.sensorUnavailable {
                
                let state = loadedExperiment.stateTitle ?? ""
                let title = loadedExperiment.localizedTitle + (state != "" ? "\n\n" + state : "\n")
                let message =  localize("sensorNotAvailableWarningText1") + localize("sensorDepth") + localize("sensorNotAvailableWarningText2") + "\n\n" +  (loadedExperiment.localizedDescription ?? "")
                
                showSensorNotAvailableDialogWithExperimentDetails(title, message, loadedExperiment.localizedLinks)
         
                
                return false
            }
            catch {}
        }
        
        if loadedExperiment.bluetoothDevices.count == 1, let input = loadedExperiment.bluetoothDevices.first {
            if let chosenPeripheral = chosenPeripheral {
                input.deviceAddress = chosenPeripheral.identifier
            }
        }
        
        let controller = ExperimentPageViewController(experiment: loadedExperiment)
        navigationController?.pushViewController(controller, animated: true)
        
        return true
    }
    
    func addExperimentsToCollection(_ list: [Experiment]) {
        for experiment in list {
            print("Copying \(experiment.localizedTitle)")
            do {
                try experiment.saveLocally(quiet: true, presenter: nil)
            } catch let error {
                print("Error for \(experiment.localizedTitle): \(error.localizedDescription)")
                let hud = JGProgressHUD(style: .dark)
                hud.indicatorView = JGProgressHUDErrorIndicatorView()
                hud.indicatorView?.tintColor = .white
                hud.textLabel.text = "Failed to copy experiment \(experiment.localizedTitle)"
                hud.detailTextLabel.text = error.localizedDescription
                
                (UIApplication.shared.keyWindow?.rootViewController?.view).map {
                    hud.show(in: $0)
                    hud.dismiss(afterDelay: 3.0)
                }
            }
        }
        ExperimentManager.shared.reloadUserExperiments()

        
    }
    
    func buildDeviceInfoMessage() -> String{
        var msg = "phyphox\n"
        msg += "Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")\n"
        msg += "Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?")\n"
        msg += "File format: \(latestSupportedFileVersion.major).\(latestSupportedFileVersion.minor)\n\n"
        
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String.init(validatingUTF8: ptr)
            }
        }
        
        msg += "Device\n"
        msg += "Model: \(modelCode!)\n"
        msg += "Brand: Apple\n"
        msg += "iOS version: \(UIDevice.current.systemVersion)"
        
        return msg
        
    }
    
    func getAdustedQRCodeIconAsAppMode() -> MenuTableViewController.MenuElement{
        let lightModeMenuElement = MenuTableViewController.MenuElement(label: localize("newExperimentQR"), icon: UIImage(named: "new_experiment_qr")!, callback: launchScanner)
        guard #available(iOS 13.0, *) else {
            return lightModeMenuElement
        }
        let darkModeMenuElement = MenuTableViewController.MenuElement(label: localize("newExperimentQR"), icon: (UIImage(named: "new_experiment_qr")?.withTintColor(.white, renderingMode: .alwaysOriginal))!, callback: launchScanner)
        
        if(SettingBundleHelper.getAppMode() == Utility.LIGHT_MODE){
            return lightModeMenuElement
        } else if(SettingBundleHelper.getAppMode() == Utility.DARK_MODE){
            return darkModeMenuElement
        } else {
            if(UIScreen.main.traitCollection.userInterfaceStyle == .dark){
                return darkModeMenuElement
            } else {
                return lightModeMenuElement
            }
        }
        
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                self.selfView.collectionView.reloadData()
            }
        }
    }
}
