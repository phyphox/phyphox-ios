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
    private var cellsPerRow: Int = 1
    private var infoButton: UIButton? = nil
    
    override class var viewClass: CollectionContainerView.Type {
        return MainView.self
    }
    
    override class var customCells: [String : UICollectionViewCell.Type]? {
        return ["ExperimentCell" : ExperimentCell.self]
    }
    
    override class var customHeaders: [String : UICollectionReusableView.Type]? {
        return ["Header" : ExperimentHeaderView.self]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.barTintColor = kBackgroundColor
        self.navigationController?.navigationBar.isTranslucent = true
    }
    
    @objc func showHelpMenu(_ item: UIBarButtonItem) {
        let alert = UIAlertController(title: NSLocalizedString("help", comment: ""), message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("credits", comment: ""), style: .default, handler: infoPressed))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("experimentsPhyphoxOrg", comment: ""), style: .default, handler:{ _ in
            UIApplication.shared.openURL(URL(string: NSLocalizedString("experimentsPhyphoxOrgURL", comment: ""))!)
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("faqPhyphoxOrg", comment: ""), style: .default, handler:{ _ in
            UIApplication.shared.openURL(URL(string: NSLocalizedString("faqPhyphoxOrgURL", comment: ""))!)
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("remotePhyphoxOrg", comment: ""), style: .default, handler:{ _ in
            UIApplication.shared.openURL(URL(string: NSLocalizedString("remotePhyphoxOrgURL", comment: ""))!)
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("translationInfo", comment: ""), style: .default, handler:{ _ in
            let al = UIAlertController(title: NSLocalizedString("translationInfo", comment: ""), message: NSLocalizedString("translationText", comment: ""), preferredStyle: .alert)
            
            al.addAction(UIAlertAction(title: NSLocalizedString("translationToWebsite", comment: ""), style: .default, handler: { _ in
                UIApplication.shared.openURL(URL(string: NSLocalizedString("translationToWebsiteURL", comment: ""))!)
            }))
            
            al.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
            
            self.navigationController!.present(al, animated: true, completion: nil)
        }))

        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = infoButton!
            popover.sourceRect = infoButton!.frame
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "phyphox"
        
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: NSNotification.Name(rawValue: ExperimentsReloadedNotification), object: nil)
        
        infoButton = UIButton(type: .infoDark)
        infoButton!.addTarget(self, action: #selector(showHelpMenu(_:)), for: .touchUpInside)
        infoButton!.sizeToFit()
        
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(createNewExperiment))
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: infoButton!)
        navigationItem.rightBarButtonItem = addButton
        
        let defaults = UserDefaults.standard
        let key = "donotshowagain"
        if (!defaults.bool(forKey: key)) {
            let alert = UIAlertController(title: NSLocalizedString("warning", comment: ""), message: NSLocalizedString("damageWarning", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("donotshowagain", comment: ""), style: .default, handler: { _ in
                defaults.set(true, forKey: key)
            }))
        
            alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
        
            navigationController!.present(alert, animated: true, completion: nil)
        }
    }
    
    private func showOpenSourceLicenses() {
        let alert = UIAlertController(title: "Open Source Licenses", message: PTFile.stringWithContentsOfFile(Bundle.main.path(forResource: "Licenses", ofType: "ptf")!), preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("close", comment: ""), style: .cancel, handler: nil))
        
        navigationController!.present(alert, animated: true, completion: nil)
    }
    
    func infoPressed(_ action: UIAlertAction) {
        let vc = UIViewController()
        vc.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        vc.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
        
        let v = creditsView()
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
        selfView.collectionView.reloadData()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    let overlayTransitioningDelegate = CreateViewControllerTransitioningDelegate()
    
    @objc func createNewExperiment() {
        let vc = CreateExperimentViewController()
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
    
    //MARK: - UICollectionViewDataSource
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return ExperimentManager.sharedInstance().experimentCollections.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return ExperimentManager.sharedInstance().experimentCollections[section].experiments!.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var cells: CGFloat = 1.0
        
        var width = self.view.frame.size.width
        
        while self.view.frame.size.width/(cells+1.0) >= minCellWidth {
            cells += 1.0
            width = self.view.frame.size.width/cells
        }
        
        cellsPerRow = Int(cells)
        
        
        
        
        let h = ceil(UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline).lineHeight + UIFont.preferredFont(forTextStyle: UIFontTextStyle.caption1).lineHeight + 12)
        
        return CGSize(width: width, height: h)
    }
    
    private func showDeleteConfirmationForExperiment(_ experiment: Experiment, button: UIButton) {
        let alert = UIAlertController(title: NSLocalizedString("confirmDeleteTitle", comment: ""), message: NSLocalizedString("confirmDelete", comment: ""), preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("delete", comment: "") + " \(experiment.stateTitle ?? experiment.localizedTitle)", style: .destructive, handler: { [unowned self] action in
            do {
                try ExperimentManager.sharedInstance().deleteExperiment(experiment)
            }
            catch let error as NSError {
                let hud = JGProgressHUD(style: .dark)
                hud?.interactionType = .blockTouchesOnHUDView
                hud?.indicatorView = JGProgressHUDErrorIndicatorView()
                hud?.textLabel.text = "Failed to delete experiment: \(error.localizedDescription)"
                
                hud?.show(in: self.view)
                
                hud?.dismiss(afterDelay: 3.0)
            }
            }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.navigationController!.view
            popover.sourceRect = button.convert(button.bounds, to: self.navigationController!.view)
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    private func showOptionsForExperiment(_ experiment: Experiment, button: UIButton) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("delete", comment: ""), style: .destructive, handler: { [unowned self] action in
            self.showDeleteConfirmationForExperiment(experiment, button: button)
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.navigationController!.view
            popover.sourceRect = button.convert(button.bounds, to: self.navigationController!.view)
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ExperimentCell", for: indexPath) as! ExperimentCell
        
        let collection = ExperimentManager.sharedInstance().experimentCollections[indexPath.section]
        let experiment = collection.experiments![indexPath.row]
        
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
        return CGSize(width: self.view.frame.size.width, height: 36.0)
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionElementKindSectionHeader {
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath) as! ExperimentHeaderView
            
            let collection = ExperimentManager.sharedInstance().experimentCollections[indexPath.section]
            
            view.title = collection.title
            
            return view
        }
        
        fatalError("Invalid supplementary view: \(kind)")
    }
    
    //MARK: - UICollectionViewDelegate
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: IndexPath) {
        let experiment = ExperimentManager.sharedInstance().experimentCollections[indexPath.section].experiments![indexPath.row]
        
        if let sensors = experiment.experiment.sensorInputs {
            for sensor in sensors {
                do {
                    try sensor.verifySensorAvailibility()
                }
                catch SensorError.sensorUnavailable(let type) {
                    let controller = UIAlertController(title: NSLocalizedString("sensorNotAvailableWarningTitle", comment: ""), message: NSLocalizedString("sensorNotAvailableWarningText1", comment: "") + " \(type) " + NSLocalizedString("sensorNotAvailableWarningText2", comment: ""), preferredStyle: .alert)
                    
                    controller.addAction(UIAlertAction(title: NSLocalizedString("sensorNotAvailableWarningMoreInfo", comment: ""), style: .default, handler:{ _ in
                        UIApplication.shared.openURL(URL(string: NSLocalizedString("sensorNotAvailableWarningMoreInfoURL", comment: ""))!)
                    }))
                    controller.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .cancel, handler:nil))
                    
                    present(controller, animated: true, completion: nil)
                    
                    return
                }
                catch {}
            }
        }
        
        let vc = ExperimentPageViewController(experiment: experiment.experiment)
        
        var denied = false
        var showing = false
        
        experiment.experiment.willGetActive {
            denied = true
            if showing {
                self.navigationController!.popViewController(animated: true)
            }
        }
        
        if !denied {
            navigationController!.pushViewController(vc, animated: true)
            showing = true
        }
    }
}
