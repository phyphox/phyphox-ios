//
//  GraphToolbarManager.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 04.08.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

// MARK: - Graph Toolbar

//Toolbar of the fullscreen graph. A custom view rather than a UITabBar so its items can also be
//stacked vertically along the right edge in landscape orientation, where the vertical space is
//too precious for a bottom bar - like on Android.
class GraphToolbar: UIView {

    class ItemView: UIControl {
        private let iconView = UIImageView()
        private let titleLabel = UILabel()

        var selectedItem = false {
            didSet {
                applyColors()
            }
        }

        init(title: String, image: UIImage?, tag: Int) {
            super.init(frame: .zero)
            self.tag = tag

            iconView.image = image?.withRenderingMode(.alwaysTemplate)
            iconView.contentMode = .scaleAspectFit
            iconView.isUserInteractionEnabled = false
            titleLabel.text = title
            titleLabel.font = UIFont.systemFont(ofSize: 10)
            titleLabel.textAlignment = .center
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.isUserInteractionEnabled = false
            addSubview(iconView)
            addSubview(titleLabel)
            applyColors()
        }

        @available(*, unavailable)
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func applyColors() {
            let color = selectedItem ? kHighlightColor : UIColor(named: "textColor")
            iconView.tintColor = color
            titleLabel.textColor = color
        }

        override var isHighlighted: Bool {
            didSet {
                alpha = isHighlighted ? 0.5 : 1.0
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            let iconSize: CGFloat = 24.0
            let labelHeight = titleLabel.font.lineHeight
            let contentHeight = iconSize + 2.0 + labelHeight
            let top = max(0.0, (bounds.height - contentHeight) / 2.0)
            iconView.frame = CGRect(x: (bounds.width - iconSize) / 2.0, y: top, width: iconSize, height: iconSize)
            titleLabel.frame = CGRect(x: 2.0, y: top + iconSize + 2.0, width: bounds.width - 4.0, height: labelHeight)
        }
    }

    private(set) var itemViews: [ItemView] = []
    var onSelect: ((Int) -> Void)?

    //Layout axis: false = horizontal bar at the bottom, true = vertical strip at the right edge
    var vertical = false {
        didSet {
            if vertical != oldValue {
                setNeedsLayout()
            }
        }
    }

    var selectedTag: Int = -1 {
        didSet {
            for itemView in itemViews {
                itemView.selectedItem = (itemView.tag == selectedTag)
            }
        }
    }

    private let horizontalHeight: CGFloat = 49.0
    private let verticalWidth: CGFloat = 76.0
    private let verticalItemHeight: CGFloat = 64.0

    init(items: [(title: String, image: UIImage?, tag: Int)]) {
        super.init(frame: .zero)
        backgroundColor = UIColor(named: "mainBackground")
        for item in items {
            let itemView = ItemView(title: item.title, image: item.image, tag: item.tag)
            itemView.addTarget(self, action: #selector(itemTapped(_:)), for: .touchUpInside)
            itemViews.append(itemView)
            addSubview(itemView)
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func itemTapped(_ sender: UIControl) {
        onSelect?(sender.tag)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        if vertical {
            return CGSize(width: verticalWidth, height: size.height)
        } else {
            return CGSize(width: size.width, height: horizontalHeight)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !itemViews.isEmpty else { return }
        if vertical {
            //Center the item block vertically, aligned with the middle of the graph
            let totalHeight = CGFloat(itemViews.count) * verticalItemHeight
            let top = max(0.0, (bounds.height - totalHeight) / 2.0)
            for (i, itemView) in itemViews.enumerated() {
                itemView.frame = CGRect(x: 0, y: top + CGFloat(i) * verticalItemHeight, width: bounds.width, height: verticalItemHeight)
            }
        } else {
            let itemWidth = bounds.width / CGFloat(itemViews.count)
            for (i, itemView) in itemViews.enumerated() {
                itemView.frame = CGRect(x: CGFloat(i) * itemWidth, y: 0, width: itemWidth, height: bounds.height)
            }
        }
    }
}

// MARK: - Graph Toolbar Manager
class GraphToolbarManager: NSObject {
    weak var delegate: GraphToolbarDelegate?

    private(set) var toolbar: GraphToolbar?
    private var _currentMode: GraphMode = .none

    enum GraphMode: Int {
        case panZoom = 0, pick, none
    }

    var currentMode: GraphMode { return _currentMode }

    //Custom title for the pick tool, set from the graph's pickLabel attribute.
    var pickTitle: String? = nil

    func setMode(mode: GraphMode){
        self._currentMode = mode
    }

    func handleResizableStateChange(_ state: ResizableViewModuleState) {
        if state == .exclusive {
            setupToolbar()
            delegate?.toolbarManagerSelectionMode(self)
        } else {
            toolbar?.removeFromSuperview()
            toolbar = nil
            _currentMode = .none
        }
    }

    private func setupToolbar() {
        let toolbar = GraphToolbar(items: [
            (title: localize("graph_tools_pan_and_zoom"), image: UIImage(named: "pan_zoom"), tag: GraphMode.panZoom.rawValue),
            (title: pickTitle ?? localize("graph_tools_pick"), image: UIImage(named: "pick"), tag: GraphMode.pick.rawValue),
            (title: localize("graph_tools_more"), image: UIImage(named: "more"), tag: GraphMode.none.rawValue)
        ])

        toolbar.onSelect = { [weak self] tag in
            self?.handleSelection(tag)
        }

        self.toolbar = toolbar
    }

    private func handleSelection(_ tag: Int) {
        guard let mode = GraphMode(rawValue: tag) else { return }

        if mode == .none {
            delegate?.toolbarManagerDidRequestMenu(self)
            toolbar?.selectedTag = _currentMode.rawValue
        } else {
            _currentMode = mode
            toolbar?.selectedTag = mode.rawValue
            delegate?.toolbarManager(self, didSelectMode: mode)
        }
    }
}

protocol GraphToolbarDelegate: AnyObject {
    func toolbarManager(_ manager: GraphToolbarManager, didSelectMode mode: GraphToolbarManager.GraphMode)
    func toolbarManagerDidRequestMenu(_ manager: GraphToolbarManager)
    func toolbarManagerSelectionMode(_ manager: GraphToolbarManager)
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
    
    func show(from sourceView: UIView, sourceView toolbar: GraphToolbar?) {
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
            if let menuItem = toolbar.itemViews.first(where: { $0.tag == GraphToolbarManager.GraphMode.none.rawValue }) {
                popover.sourceView = toolbar
                popover.sourceRect = menuItem.frame
            }
        }

        if let controller = menuAlertController {
            graph?.layoutDelegate?.presentDialog(controller)
        }
    }
}

extension ExperimentGraphView: GraphToolbarDelegate {
    func toolbarManagerSelectionMode(_ manager: GraphToolbarManager) {
        manager.setMode(mode: .panZoom)
        manager.toolbar?.selectedTag = GraphToolbarManager.GraphMode.panZoom.rawValue
    }

    func toolbarManager(_ manager: GraphToolbarManager, didSelectMode mode: GraphToolbarManager.GraphMode) {
        if mode != .pick {
            markerSystem.clearMarkers()
        }
    }

    func toolbarManagerDidRequestMenu(_ manager: GraphToolbarManager) {
        showToolbarMenu()
    }
}
