//
//  GraphToolbarManager.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 04.08.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

// MARK: - Graph Toolbar Manager
class GraphToolbarManager: NSObject, UITabBarDelegate {
    weak var delegate: GraphToolbarDelegate?
    
    private(set) var toolbar: UITabBar?
    private var _currentMode: GraphMode = .none
    
    enum GraphMode: Int {
        case panZoom = 0, pick, calibrate, none
    }
    
    var currentMode: GraphMode { return _currentMode }
    
    private var shouldShowCalibration: Bool = false
    
    func setShouldShowCalibration(_ show: Bool){
        shouldShowCalibration = show
        if toolbar != nil{
            setupToolbar()
        }
    }
    
    func setMode(mode: GraphMode){
        self._currentMode = mode
    }
    
    func handleResizableStateChange(_ state: ResizableViewModuleState) {
        if state == .exclusive {
            setupToolbar()
            _currentMode = .panZoom
            toolbar?.selectedItem = toolbar?.items?[GraphMode.panZoom.rawValue]
        } else {
            toolbar?.removeFromSuperview()
            toolbar = nil
            _currentMode = .none
            
        }
    }
    
    private func setupToolbar() {
        let tabBar = UITabBar()
        
        let panZoomButton = UITabBarItem(title: localize("graph_tools_pan_and_zoom"), image: UIImage(named: "pan_zoom"), tag: GraphMode.panZoom.rawValue)
        let pickButton = UITabBarItem(title: localize("graph_tools_pick"), image: UIImage(named: "pick"), tag: GraphMode.pick.rawValue)
        
        
        tabBar.items = [panZoomButton, pickButton]
        
        if shouldShowCalibration {
            var calibrationButton : UITabBarItem
            if #available(iOS 13.0, *) {
                calibrationButton = UITabBarItem(title: localize("graph_tools_calibrate"), image: UIImage(systemName: "compass.drawing"), tag: GraphMode.calibrate.rawValue)
            } else {
                calibrationButton = UITabBarItem(title: localize("graph_tools_calibrate"), image: UIImage(named: "calibration"), tag: GraphMode.calibrate.rawValue)
            }
            tabBar.items?.append(calibrationButton)
        }
        
        let menuButton = UITabBarItem(title: localize("graph_tools_more"), image: UIImage(named: "more"), tag: GraphMode.none.rawValue)
        tabBar.items?.append(menuButton)
        
        tabBar.delegate = self
        
        // Styling
        tabBar.shadowImage = UIImage()
        tabBar.backgroundImage = UIImage()
        tabBar.backgroundColor = UIColor(named: "mainBackground")
        tabBar.tintColor = kHighlightColor
        if #available(iOS 10, *) {
            tabBar.unselectedItemTintColor = UIColor(named: "textColor")
        }
        
        self.toolbar = tabBar
    }
    
    // MARK: - UITabBarDelegate
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let mode = GraphMode(rawValue: item.tag) else { return }
        
        switch mode {
        case .panZoom:
            _currentMode = .panZoom
            delegate?.toolbarManager(self, didSelectMode: .panZoom)
        case .pick:
            _currentMode = .pick
            delegate?.toolbarManager(self, didSelectMode: .pick)
        case .calibrate:
            _currentMode = .calibrate
            delegate?.toolbarManager(self, didSelectMode: .calibrate)
        case .none:
            delegate?.toolbarManagerDidRequestMenu(self)
            tabBar.selectedItem = tabBar.items?[_currentMode.rawValue]
        }
    }
}

protocol GraphToolbarDelegate: AnyObject {
    func toolbarManager(_ manager: GraphToolbarManager, didSelectMode mode: GraphToolbarManager.GraphMode)
    func toolbarManagerDidRequestMenu(_ manager: GraphToolbarManager)
}

extension ExperimentGraphView : UITableViewDataSource, UITableViewDelegate {
    func showToolbarMenu() {
       menuController = GraphMenuController(graph: self)
        menuController?.show(from: self, sourceView: toolbarManager.toolbar)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return getMenuElements().count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "")
        let (label, checked, _) = getMenuElements()[indexPath.row]
        
        cell.textLabel?.text = label
        cell.accessoryType = checked ? .checkmark : .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let (_, _, action) = getMenuElements()[indexPath.row]
        action()
        menuController?.menuAlertController?.dismiss(animated: true, completion: nil)
    }
    
    private func getMenuElements() -> [(String, Bool, () -> ())] {
        var elements: [(String, Bool, () -> ())] = []
        
        if(getSpectroscopyMode()){
            elements.append((localize("spectroscopy_reset_calibration"), false, {
                self.spectroscopyManager.resetCalibration()
            }))
            
            if spectroscopyManager.isCalibrated {
                elements.append((localize("spectroscopy_calibration_complete"), true, {}))
            }
        }
                    
        // Graph tools items
        if (descriptor.timeOnX || descriptor.timeOnY) && !graphRenderer.hasZData {
            elements.append((localize("graph_tools_system_time"), systemTime, toggleSystemTime))
        }
        
        elements.append((localize("graph_tools_reset"), false, { self.zoomManager.resetZoom() }))
        
        if descriptor.partialUpdate {
            elements.append((localize("graph_tools_follow"), zoomManager.isZoomFollows, { self.zoomManager.toggleFollow() }))
        }
        
        if !descriptor.logX && !descriptor.logY && !graphRenderer.hasZData {
            elements.append((localize("graph_tools_linear_fit"), markerSystem.isShowingLinearFit, { self.markerSystem.toggleLinearFit() }))
        }
        
        elements.append((localize("graph_tools_export"), false, exportGraphData))
        
        // Log scale items
        if descriptor.logX {
            elements.append((localize("graph_tools_log_x"), logX, { self.dataManager.toggleLogX() }))
        }
        
        if descriptor.logY {
            elements.append((localize("graph_tools_log_y"), logY, { self.dataManager.toggleLogY() }))
        }
        
        return elements
    }
    
    private func toggleSystemTime() {
        systemTime = !systemTime
    }
}

class GraphMenuController {
    private weak var graph: ExperimentGraphView?
    var menuAlertController: UIAlertController?
    
    init(graph: ExperimentGraphView) {
        self.graph = graph
    }
    
    func show(from sourceView: UIView, sourceView toolbar: UITabBar?) {
        menuAlertController = UIAlertController(title: localize("graph_tools_more"), message: nil, preferredStyle: .actionSheet)
        
        let tableView = FixedTableView()
        tableView.dataSource = graph
        tableView.delegate = graph
        tableView.isUserInteractionEnabled = true
        
        let tableViewController = UITableViewController()
        tableViewController.tableView = tableView
        menuAlertController?.setValue(tableViewController, forKey: "contentViewController")
        menuAlertController?.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler: nil))
        
        if let popover = menuAlertController?.popoverPresentationController, let toolbar = toolbar {
            let interactionViews = toolbar.subviews.filter { $0.isUserInteractionEnabled }
            if !interactionViews.isEmpty {
                let view = interactionViews.sorted(by: { $0.frame.minX < $1.frame.minX })[GraphToolbarManager.GraphMode.none.rawValue]
                popover.sourceView = toolbar
                popover.sourceRect = view.frame
            }
        }
        
        if let controller = menuAlertController {
            graph?.layoutDelegate?.presentDialog(controller)
        }
    }
}

extension ExperimentGraphView: GraphToolbarDelegate {
    func toolbarManager(_ manager: GraphToolbarManager, didSelectMode mode: GraphToolbarManager.GraphMode) {
        if mode != .pick {
            markerSystem.clearMarkers()
        }
        
        if mode == .calibrate {
            spectroscopyManager.startCalibration()
        } else {
            spectroscopyManager.setUncalibrateMode()
        }
    }
    
    func toolbarManagerDidRequestMenu(_ manager: GraphToolbarManager) {
        showToolbarMenu()
    }
}
