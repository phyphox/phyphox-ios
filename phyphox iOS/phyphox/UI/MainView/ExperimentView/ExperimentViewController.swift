//
//  ExperimentViewController.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 09.10.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

private let moduleCellID = "ModuleCell"

final class ExperimentViewController: UITableViewController {
    private let modules: [ExperimentViewModuleView]

    private let scrollView = UIScrollView()
    private let linearView = UIView()
    
    private let insetTop: CGFloat = 10
    private let intercellSpacing: CGFloat = 10

    var active = false {
        didSet {
            for var module in modules {
                module.active = active
            }
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return modules.count
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.0
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.0
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let size = modules[indexPath.row].sizeThatFits(view.frame.size)

        if indexPath.row > 0 {
            return size.height + intercellSpacing
        }
        else {
            return size.height + insetTop
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: moduleCellID, for: indexPath) as? ExperimentViewModuleTableViewCell else {
            return UITableViewCell()
        }

        let module = modules[indexPath.row]

        if indexPath.row > 0 {
            cell.topInset = intercellSpacing
        }
        else {
            cell.topInset = insetTop
        }

        // Add to new cell
        cell.module = module

        return cell
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? ExperimentViewModuleTableViewCell else { return  }

        cell.module?.active = active

        // TODO: Better protocol
        cell.module?.setNeedsUpdate()
    }

    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? ExperimentViewModuleTableViewCell else { return  }

        cell.module?.active = false
    }
    
    init(modules: [ExperimentViewModuleView]) {
        self.modules = modules

        super.init(style: .grouped)

        tableView.register(ExperimentViewModuleTableViewCell.self, forCellReuseIdentifier: moduleCellID)

        tableView.backgroundColor = kBackgroundColor
        tableView.separatorStyle = .none

        tableView.alwaysBounceVertical = false
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
