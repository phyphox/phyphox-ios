//
//  ApplyZoomDialog.swift
//  phyphox
//
//  Created by Sebastian Staacks on 28.02.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation
import UIKit

protocol ApplyZoomDialogResultDelegate {
    func applyZoomDialogResult(modeX: ApplyZoomAction, applyToX: ApplyZoomTarget, modeY: ApplyZoomAction, applyToY: ApplyZoomTarget)
}

enum ApplyZoomAction: Int {
    case reset
    case keep
    case follow
    case none
    
    var description: String {
        switch self {
        case .reset:
            return localize("applyZoomReset")
        case .keep:
            return localize("applyZoomKeep")
        case .follow:
            return localize("applyZoomFollow")
        default:
            return "None"
        }
    }
}

enum ApplyZoomTarget: Int {
    case this
    case sameVariable
    case sameUnit
    case sameAxis
    case none
    
    var description: String {
        switch self {
        case .this:
            return localize("applyZoomThis")
        case .sameVariable:
            return localize("applyZoomSameVariable")
        case .sameUnit:
            return localize("applyZoomSameUnit")
        case .sameAxis:
            return localize("applyZoomSameAxis")
        default:
            return "None"
        }
    }
}

extension ApplyZoomTarget: CaseIterable {}

class ApplyZoomDialog: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var dialogView = UIView()
    var backgroundView = UIView()
    
    let margin: CGFloat = 8.0
    let outerMargin: CGFloat = 16.0
    
    let axisControlUITableView = FixedTableView(frame: .zero, style: .grouped)

    var advanced = false
    
    var zoomActionX = ApplyZoomAction.keep
    var zoomTargetX = ApplyZoomTarget.this
    var zoomActionY = ApplyZoomAction.keep
    var zoomTargetY = ApplyZoomTarget.this
    
    let labelX: String
    let labelY: String
    
    var resultDelegate: ApplyZoomDialogResultDelegate?
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if advanced {
            if section == 0 {
                return 4
            } else {
                return 3
            }
        } else {
            return 2
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if advanced {
            return 2
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        if advanced {
            if ((indexPath.section == 0 && indexPath.row < 3) || (indexPath.section == 1 && indexPath.row < 2)) {
                cell = UITableViewCell(style: .default, reuseIdentifier: "")
                cell.textLabel?.text = ApplyZoomAction(rawValue: indexPath.row)?.description
                if indexPath.section == 0 {
                    cell.accessoryType = (zoomActionX == ApplyZoomAction(rawValue: indexPath.row) ? .checkmark : .none)
                } else {
                    cell.accessoryType = (zoomActionY == ApplyZoomAction(rawValue: indexPath.row) ? .checkmark : .none)
                }
            } else {
                cell = UITableViewCell(style: .value1, reuseIdentifier: "")
                cell.textLabel?.text = localize("applyZoomApply")
                cell.detailTextLabel?.text = ApplyZoomTarget(rawValue: indexPath.section == 0 ? zoomTargetX.rawValue : zoomTargetY.rawValue)?.description
                cell.accessoryType = .disclosureIndicator
            }
            return cell
        } else {
            cell = UITableViewCell(style: .default, reuseIdentifier: "")
            cell.textLabel?.text = ApplyZoomAction(rawValue: indexPath.row)?.description
            cell.accessoryType = (zoomActionX == ApplyZoomAction(rawValue: indexPath.row) ? .checkmark : .none)
            return cell
        }
    }
    
    func pickTarget(isY: Bool) {
        let actionsheet = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertController.Style.actionSheet)
        
        for target in ApplyZoomTarget.allCases {
            actionsheet.addAction(UIAlertAction(title: target.description, style: UIAlertAction.Style.default, handler: { (action) -> Void in
                if isY {
                    self.zoomTargetY = target
                } else {
                    self.zoomTargetX = target
                }
                self.axisControlUITableView.reloadData()
            }))
        }
        
        actionsheet.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: { (action) -> Void in
        }))
        
        present(actionsheet, animated: true, completion: nil)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if (advanced && ((indexPath.section == 0 && indexPath.row == 3) || (indexPath.section == 1 && indexPath.row == 2))) {
            pickTarget(isY: indexPath.section == 1)
        } else {
            if advanced {
                if indexPath.section == 0 {
                    zoomActionX = ApplyZoomAction(rawValue: indexPath.row) ?? ApplyZoomAction.reset
                } else {
                    zoomActionY = ApplyZoomAction(rawValue: indexPath.row) ?? ApplyZoomAction.reset
                }
            } else {
                zoomActionX = ApplyZoomAction(rawValue: indexPath.row) ?? ApplyZoomAction.reset
                zoomActionY = ApplyZoomAction(rawValue: indexPath.row) ?? ApplyZoomAction.reset
            }
            axisControlUITableView.reloadData()
        }
        axisControlUITableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if advanced {
            return UIFont.preferredFont(forTextStyle: .body).lineHeight
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if advanced {
            let frame = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: UIFont.preferredFont(forTextStyle: .body).lineHeight))
            let label = UILabel(frame: CGRect(x: outerMargin, y:  0, width: tableView.frame.size.width - 2*outerMargin, height: UIFont.preferredFont(forTextStyle: .body).lineHeight))
            label.font = UIFont.preferredFont(forTextStyle: .body)
            if (section == 0) {
                label.text = labelX
            } else {
                label.text = labelY
            }
            frame.addSubview(label)
            return frame
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }
    
    init (labelX: String, labelY: String, preselectKeep: Bool) {
        
        self.labelX = labelX
        self.labelY = labelY
        
        self.zoomActionX = preselectKeep ? ApplyZoomAction.keep : ApplyZoomAction.reset
        self.zoomActionY = preselectKeep ? ApplyZoomAction.keep : ApplyZoomAction.reset
        
        super.init(nibName: nil, bundle: nil)
        
        self.modalPresentationStyle = .overFullScreen
        
        dialogView.clipsToBounds = true
        dialogView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        
        backgroundView.backgroundColor = UIColor.black
        backgroundView.alpha = 0.6
        backgroundView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cancelDialog)))
        self.view.addSubview(backgroundView)
        
        //Title and instructions
        
        let titleView = UILabel()
        titleView.translatesAutoresizingMaskIntoConstraints = false
        titleView.text = localize("applyZoomTitle")
        titleView.font = UIFont.preferredFont(forTextStyle: .headline)
        dialogView.addSubview(titleView)
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isDirectionalLockEnabled = true
        dialogView.addSubview(scrollView)
        
        let scrollContentView = UIView()
        scrollContentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(scrollContentView)
        
        let explView = UILabel()
        explView.translatesAutoresizingMaskIntoConstraints = false
        explView.text = localize("applyZoomExplanation")
        explView.lineBreakMode = .byWordWrapping
        explView.numberOfLines = 0
        scrollContentView.addSubview(explView)
        
        axisControlUITableView.translatesAutoresizingMaskIntoConstraints = false
        axisControlUITableView.isScrollEnabled = false
        axisControlUITableView.dataSource = self
        axisControlUITableView.delegate = self
        
        scrollContentView.addSubview(axisControlUITableView)
        
        
        //Buttons
        
        let advancedSwitch = UISwitch()
        advancedSwitch.translatesAutoresizingMaskIntoConstraints = false
        advancedSwitch.addTarget(self, action: #selector(toggleAdvanced), for: .valueChanged)
        dialogView.addSubview(advancedSwitch)
        
        let advancedSwitchLabel = UILabel()
        advancedSwitchLabel.translatesAutoresizingMaskIntoConstraints = false
        advancedSwitchLabel.text = localize("applyZoomAdvanced")
        dialogView.addSubview(advancedSwitchLabel)
        
        let okButton = UIButton()
        okButton.translatesAutoresizingMaskIntoConstraints = false
        okButton.setTitle(localize("ok"), for: .normal)
        okButton.setTitleColor(UIColor.black, for: .normal)
        okButton.addTarget(self, action: #selector(confirmDialog), for: .touchUpInside)
        dialogView.addSubview(okButton)
        
        let cancelButton = UIButton()
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle(localize("cancel"), for: .normal)
        cancelButton.setTitleColor(UIColor.black, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelDialog), for: .touchUpInside)
        dialogView.addSubview(cancelButton)
        
        //...........
        
        dialogView.backgroundColor = UIColor.white
        dialogView.layer.cornerRadius = 6
        self.view.addSubview(dialogView)
        
        self.view.addConstraint(NSLayoutConstraint(item: backgroundView, attribute: .left, relatedBy: .equal, toItem: self.view, attribute: .left, multiplier: 1, constant: 0))
        self.view.addConstraint(NSLayoutConstraint(item: backgroundView, attribute: .right, relatedBy: .equal, toItem: self.view, attribute: .right, multiplier: 1, constant: 0))
        self.view.addConstraint(NSLayoutConstraint(item: backgroundView, attribute: .top, relatedBy: .equal, toItem: self.view, attribute: .top, multiplier: 1, constant: 0))
        self.view.addConstraint(NSLayoutConstraint(item: backgroundView, attribute: .bottom, relatedBy: .equal, toItem: self.view, attribute: .bottom, multiplier: 1, constant: 0))
        
        self.view.addConstraint(NSLayoutConstraint(item: dialogView, attribute: .left, relatedBy: .greaterThanOrEqual, toItem: backgroundView, attribute: .left, multiplier: 1, constant: outerMargin))
        self.view.addConstraint(NSLayoutConstraint(item: dialogView, attribute: .right, relatedBy: .lessThanOrEqual, toItem: backgroundView, attribute: .right, multiplier: 1, constant: -outerMargin))
        self.view.addConstraint(NSLayoutConstraint(item: dialogView, attribute: .width, relatedBy: .lessThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 600))
        self.view.addConstraint(NSLayoutConstraint(item: dialogView, attribute: .top, relatedBy: .greaterThanOrEqual, toItem: backgroundView, attribute: .top, multiplier: 1, constant: outerMargin))
        self.view.addConstraint(NSLayoutConstraint(item: dialogView, attribute: .bottom, relatedBy: .lessThanOrEqual, toItem: backgroundView, attribute: .bottom, multiplier: 1, constant: -outerMargin))
        
        self.view.addConstraint(NSLayoutConstraint(item: dialogView, attribute: .centerX, relatedBy: .equal, toItem: backgroundView, attribute: .centerX, multiplier: 1, constant: 0))
        self.view.addConstraint(NSLayoutConstraint(item: dialogView, attribute: .centerY, relatedBy: .equal, toItem: backgroundView, attribute: .centerY, multiplier: 1, constant: 0))
        
        //Title
        
        dialogView.addConstraint(NSLayoutConstraint(item: titleView, attribute: .top, relatedBy: .equal, toItem: dialogView, attribute: .top, multiplier: 1, constant: outerMargin))
        dialogView.addConstraint(NSLayoutConstraint(item: titleView, attribute: .left, relatedBy: .equal, toItem: dialogView, attribute: .left, multiplier: 1, constant: outerMargin))
        dialogView.addConstraint(NSLayoutConstraint(item: titleView, attribute: .right, relatedBy: .equal, toItem: dialogView, attribute: .right, multiplier: 1, constant: -outerMargin))
        
        //Scroll view and explanation
        
        dialogView.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .top, relatedBy: .equal, toItem: titleView, attribute: .bottom, multiplier: 1, constant: margin))
        dialogView.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .bottom, relatedBy: .equal, toItem: advancedSwitch, attribute: .top, multiplier: 1, constant: -2*margin))
        dialogView.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .left, relatedBy: .equal, toItem: dialogView, attribute: .left, multiplier: 1, constant: 0))
        dialogView.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .right, relatedBy: .equal, toItem: dialogView, attribute: .right, multiplier: 1, constant: 0))
        
        let heightContraint = NSLayoutConstraint(item: scrollView, attribute: .height, relatedBy: .equal, toItem: scrollContentView, attribute: .height, multiplier: 1, constant: 0)
        heightContraint.priority = .defaultLow
        dialogView.addConstraint(heightContraint)
        
        dialogView.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .top, relatedBy: .equal, toItem: scrollContentView, attribute: .top, multiplier: 1, constant: 0))
        dialogView.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .left, relatedBy: .equal, toItem: scrollContentView, attribute: .left, multiplier: 1, constant: 0))
        dialogView.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .right, relatedBy: .equal, toItem: scrollContentView, attribute: .right, multiplier: 1, constant: 0))
        dialogView.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .bottom, relatedBy: .equal, toItem: scrollContentView, attribute: .bottom, multiplier: 1, constant: 0))
        
        dialogView.addConstraint(NSLayoutConstraint(item: scrollContentView, attribute: .width, relatedBy: .equal, toItem: dialogView, attribute: .width, multiplier: 1, constant: 0))
        
        scrollContentView.addConstraint(NSLayoutConstraint(item: explView, attribute: .top, relatedBy: .equal, toItem: scrollContentView, attribute: .top, multiplier: 1, constant: margin))
        scrollContentView.addConstraint(NSLayoutConstraint(item: explView, attribute: .left, relatedBy: .equal, toItem: scrollContentView, attribute: .left, multiplier: 1, constant: outerMargin))
        scrollContentView.addConstraint(NSLayoutConstraint(item: explView, attribute: .right, relatedBy: .equal, toItem: scrollContentView, attribute: .right, multiplier: 1, constant: -outerMargin))
        
        //UITableView
        
        scrollContentView.addConstraint(NSLayoutConstraint(item: axisControlUITableView, attribute: .top, relatedBy: .equal, toItem: explView, attribute: .bottom, multiplier: 1, constant: margin))
        scrollContentView.addConstraint(NSLayoutConstraint(item: axisControlUITableView, attribute: .left, relatedBy: .equal, toItem: scrollContentView, attribute: .left, multiplier: 1, constant: 0))
        scrollContentView.addConstraint(NSLayoutConstraint(item: axisControlUITableView, attribute: .right, relatedBy: .equal, toItem: scrollContentView, attribute: .right, multiplier: 1, constant: 0))
        scrollContentView.addConstraint(NSLayoutConstraint(item: axisControlUITableView, attribute: .bottom, relatedBy: .equal, toItem: scrollContentView, attribute: .bottom, multiplier: 1, constant: 0))
        
        //Buttons
        
        dialogView.addConstraint(NSLayoutConstraint(item: advancedSwitch, attribute: .right, relatedBy: .equal, toItem: dialogView, attribute: .right, multiplier: 1, constant: -outerMargin))
        
        dialogView.addConstraint(NSLayoutConstraint(item: advancedSwitchLabel, attribute: .top, relatedBy: .equal, toItem: advancedSwitch, attribute: .top, multiplier: 1, constant: margin))
        dialogView.addConstraint(NSLayoutConstraint(item: advancedSwitchLabel, attribute: .left, relatedBy: .equal, toItem: dialogView, attribute: .left, multiplier: 1, constant: outerMargin))
        dialogView.addConstraint(NSLayoutConstraint(item: advancedSwitchLabel, attribute: .right, relatedBy: .lessThanOrEqual, toItem: advancedSwitch, attribute: .left, multiplier: 1, constant: -margin))
        
        dialogView.addConstraint(NSLayoutConstraint(item: okButton, attribute: .top, relatedBy: .equal, toItem: advancedSwitch, attribute: .bottom, multiplier: 1, constant: margin))
        dialogView.addConstraint(NSLayoutConstraint(item: okButton, attribute: .right, relatedBy: .equal, toItem: dialogView, attribute: .right, multiplier: 1, constant: -outerMargin))
        
        dialogView.addConstraint(NSLayoutConstraint(item: cancelButton, attribute: .top, relatedBy: .equal, toItem: advancedSwitch, attribute: .bottom, multiplier: 1, constant: margin))
        dialogView.addConstraint(NSLayoutConstraint(item: cancelButton, attribute: .right, relatedBy: .equal, toItem: okButton, attribute: .left, multiplier: 1, constant: -margin))
        
        dialogView.addConstraint(NSLayoutConstraint(item: cancelButton, attribute: .bottom, relatedBy: .equal, toItem: dialogView, attribute: .bottom, multiplier: 1, constant: -outerMargin))
    }
    
    override func viewDidLayoutSubviews() {
        axisControlUITableView.reloadData()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show () {
        guard let rvc = UIApplication.shared.delegate?.window??.rootViewController else {
            return
        }
        rvc.present(self, animated: true, completion: nil)
     }
    
    
    @objc func cancelDialog() {
        self.dismiss(animated: true)
    }
    
    @objc func confirmDialog() {
        resultDelegate?.applyZoomDialogResult(modeX: zoomActionX, applyToX: zoomTargetX, modeY: zoomActionY, applyToY: zoomTargetY)
        self.dismiss(animated: true)
    }
    
    @objc func toggleAdvanced(sender:UISwitch!) {
        advanced = sender.isOn
        axisControlUITableView.reloadData()
    }
}
