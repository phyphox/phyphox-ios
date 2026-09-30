//
//  ExperimentGraphView2.swift
//  phyphox

//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.

//  Refactored by Gaurav Tripathee on 04.08.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

final class ExperimentGraphView: UIView, DynamicViewModule, ResizableViewModule, DescriptorBoundViewModule, GraphViewModule, UITabBarDelegate, ZoomableViewModule, ExportingViewModule,  AnalysisLimitedViewModule, DisplayLinkListener {
    
    // MARK: - Dependencies
    let graphRenderer: GraphRenderer
    let gestureHandler: GraphGestureHandler
    var dataManager: GraphDataManager
    let zoomManager: GraphZoomManager
    let markerSystem: GraphMarkerSystem
    let toolbarManager: GraphToolbarManager
    let layoutManager: GraphLayoutManager

    let descriptor: GraphViewDescriptor
    let timeReference: ExperimentTimeReference
    private let displayLink = DisplayLink(refreshRate: 0)
    
    var systemTime: Bool {
        didSet { handleSystemTimeChange() }
    }
    
    var menuController : GraphMenuController?
    
    // MARK: - Protocol Properties
    var exportDelegate: ExportDelegate? = nil
    var layoutDelegate: ModuleExclusiveLayoutDelegate? = nil
    var zoomDelegate: ApplyZoomDelegate? = nil
    var resizableState: ResizableViewModuleState = .normal {
        didSet { handleResizableStateChange() }
    }
    var analysisRunning: Bool = false

    //Inside a stack (file format 1.21): no tap-to-maximize and no expand icon; the stack itself takes no touches
    var isStatic = false {
        didSet {
            layoutManager.isStatic = isStatic
            tapGesture?.isEnabled = !isStatic
        }
    }
    private var tapGesture: UITapGestureRecognizer? = nil

    //Data picker values written so far, aligned with descriptor.pickOutputs slots
    private var pickData: [Double?]

    //The units shown per axis, x, y, z (session state, docs/file-format/units.md): the experiment's own unless the Unit
    //system setting or the unit dialog switched them; nil for a text unit
    private(set) var displayUnitIds: [String?] = [nil, nil, nil]
    var hasPickOutputs: Bool {
        return descriptor.pickOutputs.contains(where: { $0 != nil })
    }

    var active = false {
        didSet {
            dataManager.active = active
            displayLink.active = active
            if active { dataManager.setNeedsUpdate() }
        }
    }

    var isViewVisible: Bool = true
    
    // MARK: - Initialization
    required init?(descriptor: GraphViewDescriptor, resourceFolder: URL?) {
        self.descriptor = descriptor
        self.timeReference = descriptor.timeReference
        self.systemTime = descriptor.systemTime
        
        self.pickData = [Double?](repeating: nil, count: descriptor.pickOutputs.count)

        // Initialize components
        self.graphRenderer = GraphRenderer(descriptor: descriptor)
        //The data manager owns the log-scale state (the menu can toggle it); zoom and markers read it from there
        self.dataManager = GraphDataManager(descriptor: descriptor, timeReference: timeReference)
        self.zoomManager = GraphZoomManager(descriptor: descriptor, dataManager: dataManager)
        self.gestureHandler = GraphGestureHandler()
        self.markerSystem = GraphMarkerSystem(descriptor: descriptor, timeReference: timeReference, graphRenderer: graphRenderer, dataManager: dataManager)
        self.toolbarManager = GraphToolbarManager()
        self.layoutManager = GraphLayoutManager(descriptor: descriptor, gridView: graphRenderer.gridView, zGridView: graphRenderer.zGridView)

        super.init(frame: .zero)

        layoutManager.setupSubviews(renderer: graphRenderer, markerSystem: markerSystem)
        addSubview(layoutManager.graphArea)

        setupPicker()
        setupDelegates()
        setupGestures()
        registerForBufferUpdates()
        attachDisplayLink(displayLink)

        //The Unit system setting is applied on every load (units.md, "The unit-system setting")
        let setting = SettingBundleHelper.getUnitSystem()
        for axis in 0..<3 {
            displayUnitIds[axis] = descriptor.unitId(axis: axis)
            if let id = descriptor.unitId(axis: axis), isAxisConvertible(axis) {
                displayUnitIds[axis] = Units.forSetting(id, setting)
            }
        }
        applyDisplayUnits()
    }

    // MARK: - Display units

    //A referenced unit with a quantity, unless the axis shows a clock (units.md, "Elements that are not converted")
    func isAxisConvertible(_ axis: Int) -> Bool {
        guard Units.isConvertible(descriptor.unitId(axis: axis)) else { return false }
        let timeAxis = axis == 0 ? descriptor.timeOnX : (axis == 1 && descriptor.timeOnY)
        return !(timeAxis && systemTime)
    }

    //The conversion and symbol per axis as currently shown
    var displayUnits: GraphDisplayUnits {
        var units = GraphDisplayUnits(descriptor: descriptor)
        for axis in 0..<3 {
            guard isAxisConvertible(axis), let from = descriptor.unitId(axis: axis), let to = displayUnitIds[axis], to != from else { continue }
            units.conversions[axis] = UnitConversion(from: from, to: to)
            units.symbols[axis] = Units.symbol(to)
        }
        return units
    }

    //What the unit dialog does for an axis: show it in another unit of the same quantity
    func setDisplayUnit(axis: Int, id: String) {
        guard Units.isConvertible(descriptor.unitId(axis: axis)), Units.sameQuantity(descriptor.unitId(axis: axis), id) else { return }
        displayUnitIds[axis] = id
        applyDisplayUnits()
    }

    //Tics, titles and read-outs follow the display units; the data and the ranges stay in the experiment's
    private func applyDisplayUnits() {
        let units = displayUnits
        dataManager.setDisplayUnits(units)
        markerSystem.displayUnits = units
        layoutManager.updateAxisLabels(systemTime: systemTime, units: units)
        setNeedsLayout()
        dataManager.setNeedsUpdate()
        markerSystem.refreshMarkers()
    }

    //A tap on an axis title in exclusive mode: the unit dialog for that axis (units.md, "Switching a unit by hand")
    func showUnitDialog(axis: Int) {
        guard isAxisConvertible(axis), let id = descriptor.unitId(axis: axis) else { return }
        UnitDialog.show(from: hostingViewController, sourceView: layoutManager.axisLabelView(axis), experimentUnitId: id, currentUnitId: displayUnitIds[axis] ?? id) { [weak self] chosen in
            self?.setDisplayUnit(axis: axis, id: chosen)
        }
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupDelegates() {
        dataManager.delegate = self
        gestureHandler.delegate = self
        zoomManager.delegate = self
        //A followX graph follows from the first frame on, not only after the first zoom gesture (as on Android)
        zoomManager.notifyDataManager(dataManager)
        markerSystem.delegate = self
        toolbarManager.delegate = self
        graphRenderer.gridView.delegate = self
        graphRenderer.zGridView?.delegate = self
    }
    
    private func setupGestures() {
        gestureHandler.setupGestures(on: layoutManager.graphArea, plotView: graphRenderer.plotView)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapp(_:)))
        tapGesture.isEnabled = !isStatic
        layoutManager.graphArea.addGestureRecognizer(tapGesture)
        self.tapGesture = tapGesture
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reload),
            name: .experimentsReloadedNotification,
            object: nil
        )
    }
    
    private func registerForBufferUpdates() {
        for i in 0..<descriptor.yInputBuffers.count {
            registerForUpdatesFromBuffer(descriptor.yInputBuffers[i])
            if let xBuffer = descriptor.xInputBuffers[i] {
                registerForUpdatesFromBuffer(xBuffer)
            }
            if let zBuffer = descriptor.zInputBuffers[i] {
                registerForUpdatesFromBuffer(zBuffer)
            }
        }
        
        if let visibilityBuffer = descriptor.visibilityBuffer {
            registerForUpdatesFromBuffer(visibilityBuffer)
        }

        for output in descriptor.pickOutputs {
            if let output = output {
                registerForUpdatesFromBuffer(output.buffer)
            }
        }

    }

    // MARK: - Data picker
    private func setupPicker() {
        guard hasPickOutputs else { return }

        toolbarManager.pickTitle = descriptor.localizedPickLabel

        var buttons: [(slot: Int, title: String)] = []
        for (slot, output) in descriptor.pickOutputs.enumerated() {
            //Only the plain slots get a button; the cal slot after them is set through a value prompt
            guard let output = output, slot % 2 == 0 else { continue }
            buttons.append((slot: slot, title: descriptor.translation?.localizeString(output.label) ?? output.label))
        }
        layoutManager.pickButtons = buttons
        layoutManager.onPickButtonTapped = { [weak self] slot in
            self?.handlePickButton(slot: slot)
        }
    }

    private func handlePickButton(slot: Int) {
        guard slot < descriptor.pickOutputs.count, let output = descriptor.pickOutputs[slot] else { return }
        guard let point = markerSystem.selectedPickPoint() else { return }

        let value: Double
        switch (slot % 6) / 2 {
        case 0: value = point.x
        case 1: value = point.y
        default: value = point.z
        }

        let calSlot = slot + 1
        if calSlot < descriptor.pickOutputs.count, let calOutput = descriptor.pickOutputs[calSlot] {
            let title = descriptor.translation?.localizeString(output.label) ?? output.label
            let message = descriptor.translation?.localizeString(calOutput.label) ?? calOutput.label
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addTextField { [weak self] textField in
                textField.keyboardType = .numbersAndPunctuation
                if let previous = self?.pickData[calSlot], !previous.isNaN {
                    textField.text = String(previous)
                }
            }
            alert.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: localize("ok"), style: .default) { [weak self] _ in
                guard let text = alert.textFields?.first?.text,
                      let calValue = Double(text.replacingOccurrences(of: ",", with: ".")) else { return }
                self?.writePick(slot: slot, value: value)
                self?.writePick(slot: calSlot, value: calValue)
                self?.updatePickAnnotations()
            })
            layoutDelegate?.presentDialog(alert)
        } else {
            writePick(slot: slot, value: value)
            updatePickAnnotations()
        }
    }

    private func writePick(slot: Int, value: Double) {
        pickData[slot] = value
        descriptor.pickOutputs[slot]?.buffer.replaceValues([value])
        //Like any user input (and on Android), a pick triggers an analysis run even while paused
        descriptor.pickOutputs[slot]?.buffer.triggerUserInput()
    }

    //Re-read every update (as on Android): analysis or a clear may change pick buffers; empty or NaN removes the annotation
    func syncPickDataFromBuffers() {
        guard hasPickOutputs else { return }
        var changed = false
        for (slot, output) in descriptor.pickOutputs.enumerated() {
            guard let output = output else { continue }
            let value = output.buffer.last
            let unchanged = value == pickData[slot] || (value?.isNaN == true && pickData[slot]?.isNaN == true)
            if !unchanged {
                pickData[slot] = value
                changed = true
            }
        }
        if changed {
            updatePickAnnotations()
        }
    }

    private func updatePickAnnotations() {
        var annotations: [GraphMarkerSystem.PickAnnotation] = []
        for (slot, output) in descriptor.pickOutputs.enumerated() {
            guard let output = output, slot % 2 == 0, let value = pickData[slot], !value.isNaN else { continue }
            let axis = (slot % 6) / 2
            if axis == 2 { continue } //z picks are not drawn, as on Android

            var label = descriptor.translation?.localizeString(output.label) ?? output.label
            if slot + 1 < pickData.count, descriptor.pickOutputs[slot + 1] != nil, let calValue = pickData[slot + 1], !calValue.isNaN {
                label += " → \(calValue)"
            }

            let vertical = axis == 0
            let logAxis = vertical ? dataManager.logX : dataManager.logY
            annotations.append(GraphMarkerSystem.PickAnnotation(vertical: vertical, plotValue: logAxis ? log(value) : value, label: label))
        }
        markerSystem.setPickAnnotations(annotations)
    }

    // MARK: - DynamicViewModule Protocol
    func setNeedsUpdate() {
        dataManager.setNeedsUpdate()
    }
    
    // MARK: - DisplayLinkListener Protocol
    func display(_ displayLink: DisplayLink) {
        if dataManager.wantsUpdate && !analysisRunning {
            dataManager.performUpdate()
        }
    }
    
    // MARK: - ResizableViewModule Protocol
    func resizableStateChanged(_ newState: ResizableViewModuleState) {
        layoutManager.handleResizableStateChange(newState)
        gestureHandler.handleResizableStateChange(newState,
                                                  plotView: graphRenderer.plotView,
                                                  zScaleView: graphRenderer.zScaleView)
        toolbarManager.handleResizableStateChange(newState)
        markerSystem.handleResizableStateChange(newState)
    }
    
    // MARK: - Event Handlers
    @objc  func handleTapp(_ sender: UITapGestureRecognizer) {
        guard !isStatic else { return }
        if resizableState == .normal {
            layoutDelegate?.presentExclusiveLayout(self)
        } else if let axis = layoutManager.axisLabel(at: sender.location(in: layoutManager.graphArea)), isAxisConvertible(axis) {
            showUnitDialog(axis: axis)
        } else {
            handleExitExclusiveMode()
        }
    }
    
    private func handleExitExclusiveMode() {
        if zoomManager.hasCustomZoom || systemTime {
            showZoomDialog()
        } else {
            layoutDelegate?.restoreLayout()
        }
    }
    
    private func showZoomDialog() {
        let units = displayUnits
        let dialog = ApplyZoomDialog(
            labelX: descriptor.localizedXLabel(withUnit: units.symbols[0]),
            labelY: descriptor.localizedYLabel(withUnit: units.symbols[1]),
            preselectKeep: zoomManager.previouslyKept
        )
        dialog.resultDelegate = self
        dialog.show()
    }
    
    private func handleSystemTimeChange() {
        graphRenderer.plotView.systemTime = systemTime
        graphRenderer.systemTime = systemTime
        dataManager.systemTime = systemTime
        markerSystem.systemTime = systemTime
        //A time axis converts only while it shows no clock
        applyDisplayUnits()
    }
    
    private func handleResizableStateChange() {
        resizableStateChanged(resizableState)
    }
    
    @objc private func reload() {
        graphRenderer.refresh()
        layoutSubviews()
        setNeedsDisplay()
    }
    
    // MARK: - Layout
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return layoutManager.sizeThatFits(size, resizableState: resizableState)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if resizableState == .exclusive {
            if let toolbar = toolbarManager.toolbar, toolbar.superview != self {
                addSubview(toolbar)
            }
        }

        layoutManager.layoutSubviews(
            bounds: bounds,
            resizableState: resizableState,
            toolbar: toolbarManager.toolbar
        )
        graphRenderer.updateFrames(
            graphFrame: layoutManager.graphFrame,
            zScaleFrame: layoutManager.zScaleFrame
        )
        markerSystem.updateLayout(graphFrame: layoutManager.graphFrame)
        dataManager.plotSize = layoutManager.graphFrame.size
    }
    
    // MARK: - Public Interface
    func clearData() {
        dataManager.clearData()
        graphRenderer.clearGraph()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            graphRenderer.refresh()
            markerSystem.refreshMarkers()
            graphRenderer.statusView.setNeedsDisplay()
        }
    }
}


extension ExperimentGraphView: GraphGridDelegate {
    //The grid recalculates its tick label space in its own layout pass, after the data update; the plot and marker
    //overlay must follow or they stay one update behind (which sticks when paused, e.g. after switching to this tab)
    func updatePlotArea() {
        let graphFrame = layoutManager.graphFrame
        if graphRenderer.plotView.frame != graphFrame {
            graphRenderer.updateFrames(graphFrame: graphFrame, zScaleFrame: layoutManager.zScaleFrame)
            markerSystem.updateLayout(graphFrame: graphFrame)
            markerSystem.refreshMarkers()
            dataManager.plotSize = graphFrame.size
        }
    }
}

extension ExperimentGraphView: VisibilityControllableViewModule {
    var visibilityBuffer: DataBuffer? { descriptor.visibilityBuffer }
}
