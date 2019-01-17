//
//  ExperimentViewController.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 09.10.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

private let moduleCellID = "ModuleCell"

protocol ModuleExclusiveLayoutDelegate {
    func presentExclusiveLayout(_ view: UIView)
    func restoreLayout()
    func presentDialog(_ dialog: UIAlertController)
}

final class ExperimentViewController: UITableViewController, ModuleExclusiveLayoutDelegate {
    
    private let modules: [UIView]
    var exclusiveView: UIView? = nil

    private let scrollView = UIScrollView()
    private let linearView = UIView()
    
    private let insetTop: CGFloat = 10
    private let intercellSpacing: CGFloat = 0

    var active = false {
        didSet {
            for module in modules {
                (module as? DynamicViewModule)?.active = active
            }
            if !active {
                restoreLayout()
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
        let module = modules[indexPath.row]
        if (module.isHidden) {
            return 0
        }
        
        let size = module.sizeThatFits(view.frame.size)

        if indexPath.row > 0 {
            return size.height + intercellSpacing
        }
        else {
            return size.height + (((module as? ResizableViewModule)?.resizableState == .exclusive) ? 0 : insetTop)
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
            cell.topInset = ((module as? ResizableViewModule)?.resizableState == .exclusive) ? 0 : insetTop
        }

        // Add to new cell
        cell.module = module

        return cell
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? ExperimentViewModuleTableViewCell else { return  }

        (cell.module as? DynamicViewModule)?.active = active
    }

    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? ExperimentViewModuleTableViewCell else { return  }

        (cell.module as? DynamicViewModule)?.active = false
    }
    
    init(modules: [UIView]) {
        self.modules = modules

        super.init(style: .grouped)
        
        for module in modules {
            if let resizableViewModule = module as? ResizableViewModule {
                resizableViewModule.layoutDelegate = self
            }
        }

        tableView.register(ExperimentViewModuleTableViewCell.self, forCellReuseIdentifier: moduleCellID)

        tableView.backgroundColor = kBackgroundColor
        tableView.separatorStyle = .none

        tableView.alwaysBounceVertical = false

        // TODO: table view top content inset on iOS < 11.
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func presentExclusiveLayout(_ view: UIView) {
        exclusiveView = view
        for module in modules {
            if (module == view) {
                (module as? ResizableViewModule)?.switchResizableState(.exclusive)
            } else {
                (module as? ResizableViewModule)?.switchResizableState(.hidden)
                module.isHidden = true
            }
            self.tableView.reloadData()
        }
    }
    
    func restoreLayout() {
        exclusiveView = nil
        for module in modules {
            (module as? ResizableViewModule)?.switchResizableState(.normal)
            module.isHidden = false
        }
        self.tableView.reloadData()
    }
    
    func presentDialog(_ dialog: UIAlertController) {
        present(dialog, animated: true, completion: nil)
    }
}
