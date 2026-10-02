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
    func applyZoomDialogResult(modeX: ApplyZoomAction, applyToX: ApplyZoomTarget, modeY: ApplyZoomAction, applyToY: ApplyZoomTarget, modeZ: ApplyZoomAction)
}

enum ApplyZoomAction: Int {
    case reset
    case keep
    case follow
    case none

    var description: String {
        switch self {
        case .reset:
            return localize("applyZoomActionReset")
        case .keep:
            return localize("applyZoomActionKeep")
        case .follow:
            return localize("applyZoomActionFollow")
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
}

//The decision behind "Keep this view?" when a maximized graph is left with a zoom (ExperimentGraphView.showZoomDialog):
//what the buttons and the per-axis controls start from. Mirrors Android's ApplyZoomChoice; which axes count as zoomed
//is GraphZoomManager.isZoomed(axis:).
enum ApplyZoomChoice {
    //The emphasised button: Keep once the user has kept a zoom before, Reset otherwise
    static func defaultAction(previouslyKept: Bool) -> ApplyZoomAction {
        return previouslyKept ? .keep : .reset
    }

    //What an axis control starts from: the simple choice on every zoomed axis; Keep on a following incremental x axis is
    //"keep and follow new data"
    static func initialAxisAction(axis: Int, zoomed: Bool, simple: ApplyZoomAction, incrementalX: Bool, follows: Bool) -> ApplyZoomAction {
        if !zoomed || simple == .reset {
            return .reset
        }
        if axis == 0 && incrementalX && follows {
            return .follow
        }
        return .keep
    }
}

//"Keep this view?": two direct buttons answer it, "More options…" expands one section per zoomed axis (headed by its
//label and range) with reset / keep / follow and "Also apply to other graphs with…", and turns the buttons into Cancel/OK
class ApplyZoomDialog: UIViewController, UITableViewDataSource, UITableViewDelegate {
    //One zoomed axis as the dialog offers it
    struct Axis {
        let axis: Int                   //0 x, 1 y, 2 z
        let title: String               //label and zoomed range, e.g. "t: 2.0 s to 4.5 s"
        let keepAction: ApplyZoomAction //what "Keep this section" means here: .follow on a following incremental x axis, else .keep
        let offersFollow: Bool          //an incremental x axis
        let unitSymbol: String?         //offered as "the same unit (…)" target, nil without a unit
        var action: ApplyZoomAction = .reset
        var target: ApplyZoomTarget = .this

        var offersApplyTo: Bool { return axis < 2 }
        var actions: [ApplyZoomAction] { return offersFollow ? [.reset, .keep, .follow] : [.reset, .keep] }
        var targets: [ApplyZoomTarget] { return unitSymbol == nil ? [.this, .sameVariable, .sameAxis] : [.this, .sameVariable, .sameUnit, .sameAxis] }

        func targetTitle(_ target: ApplyZoomTarget) -> String {
            switch target {
            case .this: return localize("applyZoomTargetThis")
            case .sameVariable: return localize("applyZoomTargetSameData")
            case .sameUnit: return String(format: localize("applyZoomTargetSameUnit"), unitSymbol ?? "")
            case .sameAxis: return String(format: localize("applyZoomTargetSameAxis"), axis == 0 ? "x" : "y")
            case .none: return "None"
            }
        }
    }

    private let dialogView = UIView()
    private let backgroundView = UIView()

    private let margin: CGFloat = 8.0
    private let outerMargin: CGFloat = 16.0

    private let axisControlUITableView = FixedTableView(frame: .zero, style: .grouped)
    private var tableWidthLaidOut: CGFloat = 0

    private var axes: [Axis]
    private let defaultAction: ApplyZoomAction
    private var expanded = false

    private let moreButton: UIButton
    private let cancelButton: UIButton
    private let resetButton: UIButton
    private let keepButton: UIButton
    private let okButton: UIButton
    private let actionRow = UIStackView()
    private let moreRow = UIStackView()

    var resultDelegate: ApplyZoomDialogResultDelegate?
    var onCancel: (() -> Void)?

    //axes: the zoomed axes; defaultAction: the emphasised button (ApplyZoomChoice.defaultAction)
    init(axes: [Axis], defaultAction: ApplyZoomAction) {
        self.axes = axes
        self.defaultAction = defaultAction

        moreButton = ApplyZoomDialog.makeButton(localize("applyZoomMoreOptions"))
        cancelButton = ApplyZoomDialog.makeButton(localize("cancel"))
        resetButton = ApplyZoomDialog.makeButton(localize("applyZoomActionReset"), emphasised: defaultAction == .reset)
        keepButton = ApplyZoomDialog.makeButton(localize("applyZoomActionKeep"), emphasised: defaultAction != .reset)
        okButton = ApplyZoomDialog.makeButton(localize("ok"))

        super.init(nibName: nil, bundle: nil)

        self.modalPresentationStyle = .overFullScreen

        moreButton.addTarget(self, action: #selector(expandOptions), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelDialog), for: .touchUpInside)
        resetButton.addTarget(self, action: #selector(chooseReset), for: .touchUpInside)
        keepButton.addTarget(self, action: #selector(chooseKeep), for: .touchUpInside)
        okButton.addTarget(self, action: #selector(confirmOptions), for: .touchUpInside)
        okButton.isHidden = true

        buildLayout()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func makeButton(_ title: String, emphasised: Bool = false) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        config.baseForegroundColor = UIColor(named: "textColor")
        //One line per button; where the row does not fit, the buttons stack (viewDidLayoutSubviews)
        config.titleLineBreakMode = .byTruncatingTail
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: emphasised ? .headline : .body)
            return attributes
        }
        let button = UIButton(configuration: config)
        button.accessibilityLabel = title
        return button
    }

    private func buildLayout() {
        dialogView.clipsToBounds = true
        dialogView.translatesAutoresizingMaskIntoConstraints = false
        dialogView.backgroundColor = UIColor(named: "mainBackground")
        dialogView.layer.cornerRadius = 6
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.backgroundColor = UIColor(named: "backgroundDark")
        backgroundView.alpha = 0.6
        backgroundView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cancelDialog)))
        view.addSubview(backgroundView)
        view.addSubview(dialogView)

        let titleView = UILabel()
        titleView.text = localize("applyZoomQuestionTitle")
        titleView.textColor = UIColor(named: "textColor")
        titleView.font = UIFont.preferredFont(forTextStyle: .headline)
        titleView.numberOfLines = 0

        let questionView = UILabel()
        questionView.text = localize("applyZoomQuestion")
        questionView.textColor = UIColor(named: "textColor")
        questionView.numberOfLines = 0

        axisControlUITableView.isScrollEnabled = false
        axisControlUITableView.dataSource = self
        axisControlUITableView.delegate = self
        axisControlUITableView.isHidden = true

        //Title, then the question and the per-axis sections in a scroll view, then the buttons
        let contentStack = UIStackView(arrangedSubviews: [questionView, axisControlUITableView])
        contentStack.axis = .vertical
        contentStack.spacing = margin
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: outerMargin, bottom: 0, trailing: outerMargin)

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.addSubview(contentStack)

        actionRow.axis = .horizontal
        actionRow.spacing = margin
        actionRow.alignment = .center
        for button in [cancelButton, resetButton, keepButton, okButton] {
            actionRow.addArrangedSubview(button)
        }
        let actionRowWrapper = UIStackView(arrangedSubviews: [UIView(), actionRow])
        actionRowWrapper.axis = .horizontal
        actionRowWrapper.alignment = .center
        moreRow.addArrangedSubview(moreButton)
        moreRow.addArrangedSubview(UIView())
        moreRow.axis = .horizontal
        let buttonStack = UIStackView(arrangedSubviews: [moreRow, actionRowWrapper])
        buttonStack.axis = .vertical
        buttonStack.spacing = 0
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        buttonStack.isLayoutMarginsRelativeArrangement = true
        buttonStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: margin, bottom: 0, trailing: margin)

        let titleWrapper = UIStackView(arrangedSubviews: [titleView])
        titleWrapper.isLayoutMarginsRelativeArrangement = true
        titleWrapper.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: outerMargin, bottom: 0, trailing: outerMargin)

        let outerStack = UIStackView(arrangedSubviews: [titleWrapper, scrollView, buttonStack])
        outerStack.axis = .vertical
        outerStack.spacing = margin
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.isLayoutMarginsRelativeArrangement = true
        outerStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: outerMargin, leading: 0, bottom: margin, trailing: 0)
        dialogView.addSubview(outerStack)

        //The scroll view takes the content height where it fits and scrolls otherwise
        let heightConstraint = scrollView.heightAnchor.constraint(equalTo: contentStack.heightAnchor)
        heightConstraint.priority = .defaultLow

        NSLayoutConstraint.activate([
            backgroundView.leftAnchor.constraint(equalTo: view.leftAnchor),
            backgroundView.rightAnchor.constraint(equalTo: view.rightAnchor),
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            dialogView.leftAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leftAnchor, constant: outerMargin),
            dialogView.rightAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.rightAnchor, constant: -outerMargin),
            dialogView.widthAnchor.constraint(lessThanOrEqualToConstant: 600),
            dialogView.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: outerMargin),
            dialogView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -outerMargin),
            dialogView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dialogView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            outerStack.topAnchor.constraint(equalTo: dialogView.topAnchor),
            outerStack.bottomAnchor.constraint(equalTo: dialogView.bottomAnchor),
            outerStack.leftAnchor.constraint(equalTo: dialogView.leftAnchor),
            outerStack.rightAnchor.constraint(equalTo: dialogView.rightAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.leftAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leftAnchor),
            contentStack.rightAnchor.constraint(equalTo: scrollView.contentLayoutGuide.rightAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            heightConstraint
        ])
        //A wide dialog on a tablet: the width follows the content; the dialog never gets narrower than its buttons need
        let preferredWidth = dialogView.widthAnchor.constraint(equalToConstant: 600)
        preferredWidth.priority = .defaultLow
        preferredWidth.isActive = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        //Three buttons side by side where they fit, stacked on a narrow phone or with a large text size
        let fitting = actionRow.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width
        let available = dialogView.bounds.width - 2 * margin
        let axis: NSLayoutConstraint.Axis = fitting > available ? .vertical : .horizontal
        if actionRow.axis != axis {
            actionRow.axis = axis
            actionRow.alignment = axis == .vertical ? .trailing : .center
        }
        if axisControlUITableView.bounds.width != tableWidthLaidOut {
            tableWidthLaidOut = axisControlUITableView.bounds.width
            axisControlUITableView.reloadData()
        }
    }

    func show () {
        guard let rvc = UIApplication.shared.delegate?.window??.rootViewController else {
            return
        }
        rvc.present(self, animated: true, completion: nil)
    }

    // MARK: - Buttons

    //The per-axis controls start from the action the emphasised button would have taken
    @objc private func expandOptions() {
        for i in axes.indices {
            axes[i].action = defaultAction == .reset ? .reset : axes[i].keepAction
            axes[i].target = .this
        }
        expanded = true
        axisControlUITableView.isHidden = false
        axisControlUITableView.reloadData()
        moreRow.isHidden = true
        resetButton.isHidden = true
        keepButton.isHidden = true
        okButton.isHidden = false
        view.setNeedsLayout()
    }

    @objc private func chooseReset() {
        finish { _ in .reset }
    }

    @objc private func chooseKeep() {
        finish { axis in axis.keepAction }
    }

    @objc private func confirmOptions() {
        finish { axis in axis.action }
    }

    //Axes the dialog did not list are not zoomed; a reset leaves them as they are
    private func finish(action: (Axis) -> ApplyZoomAction) {
        var modes: [ApplyZoomAction] = [.reset, .reset, .reset]
        var targets: [ApplyZoomTarget] = [.this, .this]
        for axis in axes {
            modes[axis.axis] = action(axis)
            if axis.offersApplyTo && expanded {
                targets[axis.axis] = axis.target
            }
        }
        resultDelegate?.applyZoomDialogResult(modeX: modes[0], applyToX: targets[0], modeY: modes[1], applyToY: targets[1], modeZ: modes[2])
        self.dismiss(animated: true)
    }

    @objc func cancelDialog() {
        onCancel?()
        self.dismiss(animated: true)
    }

    // MARK: - Per-axis sections

    func numberOfSections(in tableView: UITableView) -> Int {
        return expanded ? axes.count : 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let axis = axes[section]
        return axis.actions.count + (axis.offersApplyTo ? 1 : 0)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let axis = axes[indexPath.section]
        if indexPath.row < axis.actions.count {
            let action = axis.actions[indexPath.row]
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = action.description
            cell.accessoryType = axis.action == action ? .checkmark : .none
            return cell
        }
        //The chosen target below the question, so that neither is truncated on a phone
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = localize("applyZoomAlsoApply")
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.text = axis.targetTitle(axis.target)
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.textColor = UIColor(named: "highlightColor")
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let axis = axes[indexPath.section]
        if indexPath.row < axis.actions.count {
            axes[indexPath.section].action = axis.actions[indexPath.row]
            axisControlUITableView.reloadData()
        } else {
            let sourceView = tableView.cellForRow(at: indexPath)?.detailTextLabel ?? tableView
            pickTarget(section: indexPath.section, sourceRect: sourceView.bounds, sourceView: sourceView)
        }
        axisControlUITableView.deselectRow(at: indexPath, animated: true)
    }

    private func pickTarget(section: Int, sourceRect: CGRect, sourceView: UIView) {
        let axis = axes[section]
        let actionsheet = UIAlertController(title: localize("applyZoomAlsoApply"), message: nil, preferredStyle: .actionSheet)
        for target in axis.targets {
            actionsheet.addAction(UIAlertAction(title: axis.targetTitle(target), style: .default, handler: { [weak self] _ in
                self?.axes[section].target = target
                self?.axisControlUITableView.reloadData()
            }))
        }
        actionsheet.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler: nil))
        if let controller = actionsheet.popoverPresentationController {
            controller.sourceRect = sourceRect
            controller.sourceView = sourceView
        }
        present(actionsheet, animated: true, completion: nil)
    }

    //Each section is headed by the axis label and its zoomed range, above a divider with a gap (as on Android)
    private func headerLabel(_ section: Int, width: CGFloat) -> UILabel {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textColor = UIColor(named: "textColor")
        label.numberOfLines = 0
        label.text = axes[section].title
        label.frame = CGRect(x: outerMargin, y: 0, width: max(width - 2 * outerMargin, 0), height: 0)
        label.sizeToFit()
        label.frame.size.width = max(width - 2 * outerMargin, 0)
        return label
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return headerLabel(section, width: tableView.bounds.width).frame.height + 2 * margin + 1
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label = headerLabel(section, width: tableView.bounds.width)
        let frame = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: label.frame.height + 2 * margin + 1))
        let divider = UIView(frame: CGRect(x: outerMargin, y: 0, width: max(tableView.bounds.width - 2 * outerMargin, 0), height: 1))
        divider.backgroundColor = UIColor(named: "separatorColor")
        frame.addSubview(divider)
        label.frame.origin.y = margin + 1
        frame.addSubview(label)
        return frame
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return margin
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
}
