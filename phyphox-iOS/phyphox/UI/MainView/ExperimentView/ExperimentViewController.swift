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
}

final class ExperimentViewController: UITableViewController, ModuleExclusiveLayoutDelegate, ApplyZoomDelegate {
    
    var modules: [ExperimentModule]
    var exclusiveView: UIView? = nil
    
    private let insetTop: CGFloat = 10
    private let intercellSpacing: CGFloat = 0.0

    var active = false {
        didSet {
            for module in modules {
                (module.view as? DynamicViewModule)?.active = active
                if var resizingModule = module.view as? ResizingViewModule {
                    resizingModule.onResize = tableView?.reloadData
                }
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

        if indexPath.row > 0 {
            return size.height + (((module.view as? ResizableViewModule)?.resizableState ?? .normal == .normal) ? intercellSpacing : 0)
        }
        else {
            return size.height + (((module.view as? ResizableViewModule)?.resizableState ?? .normal == .normal) ? insetTop : 0)
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: moduleCellID, for: indexPath) as? ExperimentViewModuleTableViewCell else {
            return UITableViewCell()
        }

        let module = modules[indexPath.row]

        if indexPath.row > 0 {
            cell.topInset = ((module.view as? ResizableViewModule)?.resizableState ?? .normal == .normal) ? intercellSpacing : 0
        }
        else {
            cell.topInset = ((module.view as? ResizableViewModule)?.resizableState ?? .normal == .normal) ? insetTop : 0
        }
        
        // Add to new cell
        cell.module = module.view

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
    
    init(modules: [ExperimentModule]) {
        self.modules = modules

        super.init(style: .grouped)
                
        for module in modules {
            if let resizableViewModule = module.view as? ResizableViewModule {
                resizableViewModule.layoutDelegate = self
            }
            if let zoomableViewModule = module.view as? ZoomableViewModule {
                zoomableViewModule.zoomDelegate = self
            }
            if let vcm = module.view as? VisibilityControllableViewModule, let buffer = vcm.visibilityBuffer {
                buffer.addObserver(self)
            }
        }
        
        tableView.register(ExperimentViewModuleTableViewCell.self, forCellReuseIdentifier: moduleCellID)

        tableView.backgroundColor = UIColor(named: "mainBackground")
        tableView.separatorStyle = .none

        tableView.alwaysBounceVertical = false
        tableView.estimatedRowHeight = min(view.frame.width, view.frame.height)
        
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func presentExclusiveLayout(_ view: UIView) {
        exclusiveView = view
        for (index, module) in modules.enumerated() {
            if (module.view == view) {
                (module.view as? ResizableViewModule)?.switchResizableState(.exclusive)
                module.view?.isHidden = false
                modules[index].isVisible = true
            } else {
                (module.view as? ResizableViewModule)?.switchResizableState(.hidden)
                module.view?.isHidden = true
                modules[index].isVisible = false
            }
        }
        self.tableView.reloadData()
    }
    
    func restoreLayout() {
        exclusiveView = nil
        for module in modules {
            (module.view as? ResizableViewModule)?.switchResizableState(.normal)
            module.view?.isHidden = false
            
        }
        updateModuleVisibilities()
        self.tableView.reloadData()
    }
    
    private func updateModuleVisibilities() {
        guard exclusiveView == nil else { return }
        for (index, module) in modules.enumerated() {
            if let vcm = module.view as? VisibilityControllableViewModule, let buffer = vcm.visibilityBuffer {
                let isVisible = (buffer.last ?? 1.0) > 0.0 && buffer.size != 0
                modules[index].isVisible = isVisible
                module.view?.isHidden = !isVisible
            }
        }
    }
    
    
    func presentDialog(_ dialog: UIAlertController) {
        present(dialog, animated: true, completion: nil)
    }
    
    func applyZoom(modeX: ApplyZoomAction, applyToX: ApplyZoomTarget, targetX: String?, modeY: ApplyZoomAction, applyToY: ApplyZoomTarget, targetY: String?, zoomMin: GraphPoint2D<Double>, zoomMax: GraphPoint2D<Double>, systemTime: Bool) {
        
        for module in modules {
            if let zoomableViewModule = module.view as? ZoomableViewModule {
                zoomableViewModule.applyZoom(modeX: modeX, applyToX: applyToX, targetX: targetX, modeY: modeY, applyToY: applyToY, targetY: targetY, zoomMin: zoomMin, zoomMax: zoomMax, systemTime: systemTime)
            }
        }
    }
}


extension ExperimentViewController: DataBufferObserver {
    func dataBufferUpdated(_ buffer: DataBuffer) {
        // Only update visibilities if not in exclusive mode
        guard exclusiveView == nil else { return }
        for (index, module) in modules.enumerated() {
            if let vcm = module.view as? VisibilityControllableViewModule, vcm.visibilityBuffer === buffer {
                let isVisible = (buffer.last ?? 1.0) > 0.0 && buffer.size != 0
                modules[index].isVisible = isVisible
                module.view?.isHidden = !isVisible
            }
        }
        tableView.reloadData()
    }
    func userInputTriggered(_ buffer: DataBuffer) {}
}

