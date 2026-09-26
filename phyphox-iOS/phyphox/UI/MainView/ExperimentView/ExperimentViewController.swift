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

final class ExperimentModule {
    var view: UIView?
    var isVisible: Bool
    
    init(view: UIView?, isVisible: Bool) {
        self.view = view
        self.isVisible = isVisible
    }

    ///The row's module and, for a view group, every module below it (ExperimentGroupViews.swift)
    var moduleTree: [UIView] {
        return view?.moduleTree ?? []
    }
}

final class ExperimentViewController: UITableViewController, ModuleExclusiveLayoutDelegate, ApplyZoomDelegate {
    
    var modules: [ExperimentModule]
    var exclusiveView: UIView? = nil
    
    private let insetTop: CGFloat = 10
    private let intercellSpacing: CGFloat = 0.0

    var active = false {
        didSet {
            for view in modules.flatMap({ $0.moduleTree }) {
                (view as? DynamicViewModule)?.active = active
                if var resizingModule = view as? ResizingViewModule {
                    resizingModule.onResize = tableView?.reloadData
                }
            }
            if !active {
                restoreLayout()
            }
        }
    }

    ///A row keeps its inset unless its module, or a leaf inside its view group, is maximized or hidden by a maximized one
    private func isNormalRow(_ module: ExperimentModule) -> Bool {
        if let resizable = module.view as? ResizableViewModule {
            return resizable.resizableState == .normal
        }
        guard let exclusiveView = exclusiveView else { return true }
        return !module.moduleTree.contains(where: { $0 === exclusiveView }) && !(module.view?.isHidden ?? false)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return modules.count
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let module = modules[indexPath.row]
        
        guard let moduleView = module.view else { return 0 }
        
        if (moduleView.isHidden) { return 0 }
        
        let availableSize = view.frame.inset(by: tableView.contentInset).size
        let size = moduleView.sizeThatFits(CGSize(width: availableSize.width, height: max(availableSize.height-20, 0)))
        //TODO: The source for the value -20 is not clear. It seems like the scroll features adds a padding, but I could not find how to control it or read the correct value programmatically

        let spacing = isNormalRow(module) ? (indexPath.row > 0 ? intercellSpacing : insetTop) : 0
        let height = size.height + spacing
        //A non-finite or negative height (corrupt image, zero-aspect graph) would make UITableView throw in reloadData
        return height.isFinite ? Swift.max(height, 0) : 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: moduleCellID, for: indexPath) as? ExperimentViewModuleTableViewCell else {
            return UITableViewCell()
        }

        let module = modules[indexPath.row]

        if indexPath.row > 0 {
            cell.topInset = isNormalRow(module) ? intercellSpacing : 0
        }
        else {
            cell.topInset = isNormalRow(module) ? insetTop : 0
        }
        
        // Add to new cell
        cell.module = module.view

        return cell
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? ExperimentViewModuleTableViewCell else { return  }

        for view in cell.module?.moduleTree ?? [] {
            (view as? DynamicViewModule)?.active = active
        }
    }

    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? ExperimentViewModuleTableViewCell else { return  }

        for view in cell.module?.moduleTree ?? [] {
            (view as? DynamicViewModule)?.active = false
        }
    }
    
    init(modules: [ExperimentModule]) {
        self.modules = modules

        super.init(style: .grouped)
                
        for view in modules.flatMap({ $0.moduleTree }) {
            if let resizableViewModule = view as? ResizableViewModule {
                resizableViewModule.layoutDelegate = self
            }
            if let zoomableViewModule = view as? ZoomableViewModule {
                zoomableViewModule.zoomDelegate = self
            }
            if let vcm = view as? VisibilityControllableViewModule, let buffer = vcm.visibilityBuffer {
                buffer.addObserver(self)
            }
        }
        
        tableView.register(ExperimentViewModuleTableViewCell.self, forCellReuseIdentifier: moduleCellID)

        tableView.backgroundColor = UIColor(named: "mainBackground")
        tableView.separatorStyle = .none

        tableView.alwaysBounceVertical = false
        tableView.estimatedRowHeight = min(view.frame.width, view.frame.height)

        //Visibility buffers may already hide elements before their first write (base contents, defaults)
        updateModuleVisibilities()

    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //The maximized leaf may sit inside a view group: its row stays and the group hides its other children
    func presentExclusiveLayout(_ view: UIView) {
        exclusiveView = view
        for (index, module) in modules.enumerated() {
            if (module.view == view) {
                (module.view as? ResizableViewModule)?.switchResizableState(.exclusive)
                module.view?.isHidden = false
                modules[index].isVisible = true
            } else if let container = module.view as? ContainerViewModule, module.moduleTree.contains(where: { $0 === view }) {
                container.presentExclusive(view)
                module.view?.isHidden = false
                modules[index].isVisible = true
            } else {
                for leaf in module.moduleTree {
                    (leaf as? ResizableViewModule)?.switchResizableState(.hidden)
                }
                module.view?.isHidden = true
                modules[index].isVisible = false
            }
        }
        self.tableView.reloadData()
    }
    
    func restoreLayout() {
        exclusiveView = nil
        for module in modules {
            (module.view as? ContainerViewModule)?.restoreExclusive()
            for view in module.moduleTree {
                (view as? ResizableViewModule)?.switchResizableState(.normal)
                view.isHidden = false
            }
        }
        updateModuleVisibilities()
        self.tableView.reloadData()
    }
    
    private func updateModuleVisibilities() {
        guard exclusiveView == nil else { return }
        for (index, module) in modules.enumerated() {
            for view in module.moduleTree {
                if let vcm = view as? VisibilityControllableViewModule, let buffer = vcm.visibilityBuffer {
                    let isVisible = (buffer.last ?? 1.0) > 0.0 && buffer.size != 0
                    view.isHidden = !isVisible
                }
            }
            modules[index].isVisible = !(module.view?.isHidden ?? true)
            module.view?.setNeedsLayout()
        }
    }
    
    
    func presentDialog(_ dialog: UIAlertController) {
        present(dialog, animated: true, completion: nil)
    }
    
    func applyZoom(modeX: ApplyZoomAction, applyToX: ApplyZoomTarget, targetX: String?, modeY: ApplyZoomAction, applyToY: ApplyZoomTarget, targetY: String?, zoomMin: GraphPoint2D<Double>, zoomMax: GraphPoint2D<Double>, systemTime: Bool) {
        
        for view in modules.flatMap({ $0.moduleTree }) {
            if let zoomableViewModule = view as? ZoomableViewModule {
                zoomableViewModule.applyZoom(modeX: modeX, applyToX: applyToX, targetX: targetX, modeY: modeY, applyToY: applyToY, targetY: targetY, zoomMin: zoomMin, zoomMax: zoomMax, systemTime: systemTime)
            }
        }
    }
}


extension ExperimentViewController: DataBufferObserver {
    func dataBufferUpdated(_ buffer: DataBuffer) {
        // Only update visibilities if not in exclusive mode
        guard exclusiveView == nil else { return }
        // Reload only if a visibility actually changed: a reload cancels touch interactions and is too heavy per analysis cycle
        var visibilityChanged = false
        for (index, module) in modules.enumerated() {
            //A child of a view group hides in place: the group re-lays out and the row height follows in the reload
            var rowChanged = false
            for view in module.moduleTree {
                if let vcm = view as? VisibilityControllableViewModule, vcm.visibilityBuffer === buffer {
                    let isVisible = (buffer.last ?? 1.0) > 0.0 && buffer.size != 0
                    if view.isHidden == isVisible {
                        view.isHidden = !isVisible
                        rowChanged = true
                    }
                }
            }
            if rowChanged {
                modules[index].isVisible = !(module.view?.isHidden ?? true)
                module.view?.setNeedsLayout()
                visibilityChanged = true
            }
        }
        if visibilityChanged {
            tableView.reloadData()
        }
    }
    func userInputTriggered(_ buffer: DataBuffer) {}
}

