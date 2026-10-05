//
//  UnitDialog.swift
//  phyphox
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import UIKit

//The dialog behind a tapped unit: every unit of the same quantity, grouped by system, the experiment's own unit
//marked as its default (docs/file-format/units.md, "Switching a unit by hand"). Shared by value, edit and graph.
//An action sheet carrying a table, like the graph's tools menu, so the groups get section headers and the current
//unit a checkmark.
final class UnitDialog: UITableViewController {
    private struct Group {
        let title: String
        let units: [Units.Definition]
    }

    private let groups: [Group]
    private let experimentUnitId: String
    private let currentUnitId: String
    private let onChosen: (String) -> Void
    private weak var alert: UIAlertController?

    private init(experimentUnitId: String, currentUnitId: String, onChosen: @escaping (String) -> Void) {
        let alternatives = Units.alternatives(experimentUnitId)
        var groups: [Group] = []
        for system in [Units.System.metric, .imperial, .common] {
            let units = alternatives.filter { $0.system == system }
            if !units.isEmpty {
                groups.append(Group(title: Units.systemTitle(system), units: units))
            }
        }
        self.groups = groups
        self.experimentUnitId = experimentUnitId
        self.currentUnitId = currentUnitId
        self.onChosen = onChosen
        super.init(style: .grouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    //The unit ids the list offers, in order (for the tests)
    static func listedUnitIds(_ experimentUnitId: String) -> [String] {
        return UnitDialog(experimentUnitId: experimentUnitId, currentUnitId: experimentUnitId, onChosen: { _ in }).groups.flatMap { $0.units.map { $0.id } }
    }

    //The label of a row: the symbol, the experiment's unit marked as default
    static func rowTitle(_ id: String, experimentUnitId: String) -> String {
        let symbol = Units.symbol(id)
        return id == experimentUnitId ? symbol + " (" + localize("unit_dialog_experiment_default") + ")" : symbol
    }

    ///Presents the dialog for a convertible unit; nothing happens for a unit without alternatives. A popover anchors to
    ///sourceRect within the source view (the label of a scale), or to the whole view.
    static func show(from presenter: UIViewController?, sourceView: UIView?, sourceRect: CGRect? = nil, experimentUnitId: String, currentUnitId: String, onChosen: @escaping (String) -> Void) {
        guard let presenter = presenter, Units.isConvertible(experimentUnitId) else { return }
        let dialog = UnitDialog(experimentUnitId: experimentUnitId, currentUnitId: currentUnitId, onChosen: onChosen)
        let alert = UIAlertController(title: localize("unit_dialog_title"), message: nil, preferredStyle: .actionSheet)
        dialog.tableView = FixedTableView(frame: .zero, style: .grouped)
        dialog.tableView.dataSource = dialog
        dialog.tableView.delegate = dialog
        dialog.tableView.accessibilityIdentifier = "unit.dialog"
        alert.setValue(dialog, forKey: "contentViewController")
        alert.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler: nil))
        if let popover = alert.popoverPresentationController, let sourceView = sourceView {
            popover.sourceView = sourceView
            popover.sourceRect = sourceRect ?? sourceView.bounds
        }
        dialog.alert = alert
        presenter.present(alert, animated: true, completion: nil)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return groups.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return groups[section].title
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groups[section].units.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        let unit = groups[indexPath.section].units[indexPath.row]
        cell.textLabel?.text = UnitDialog.rowTitle(unit.id, experimentUnitId: experimentUnitId)
        cell.accessoryType = unit.id == currentUnitId ? .checkmark : .none
        cell.accessibilityTraits = unit.id == currentUnitId ? [.selected] : []
        cell.accessibilityIdentifier = "unit." + unit.id
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let unit = groups[indexPath.section].units[indexPath.row]
        alert?.dismiss(animated: true, completion: nil)
        onChosen(unit.id)
    }
}

extension UIView {
    ///The view controller a module presents its dialogs from
    var hostingViewController: UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let controller = next as? UIViewController {
                return controller
            }
            responder = next
        }
        return nil
    }
}
