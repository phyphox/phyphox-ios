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

    //A tab change or "‹" waiting for this graph to leave exclusive mode (leaveExclusive); dropped on Cancel
    private var pendingLeaveCompletion: (() -> Void)? = nil

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
    
    //No question when nothing is zoomed, whatever the time axis shows: the clock display of this graph stays as set
    private func handleExitExclusiveMode() {
        if zoomManager.anyZoomed {
            showZoomDialog()
        } else {
            finishLeavingExclusive()
        }
    }

    //A tab change or "‹" (ResizableViewModule): the page controller waits for the answer; Cancel drops the request
    func leaveExclusive(completion: @escaping () -> Void) {
        guard resizableState == .exclusive else {
            completion()
            return
        }
        pendingLeaveCompletion = completion
        handleExitExclusiveMode()
    }

    func finishLeavingExclusive() {
        layoutDelegate?.restoreLayout()
        let completion = pendingLeaveCompletion
        pendingLeaveCompletion = nil
        completion?()
    }

    //"Keep this view?" over the zoomed axes (ApplyZoomChoice holds the rules): the emphasised button is Keep once the
    //user kept a zoom before, and the per-axis controls start from it
    private func showZoomDialog() {
        let simple = ApplyZoomChoice.defaultAction(previouslyKept: zoomManager.previouslyKept)
        let units = displayUnits
        let labels = [descriptor.localizedXLabel, descriptor.localizedYLabel, descriptor.localizedZLabel]
        let hasZAxis = descriptor.style.contains(.map)
        var axes: [ApplyZoomDialog.Axis] = []
        for axis in 0..<3 where zoomManager.isZoomed(axis: axis) && (axis < 2 || hasZAxis) {
            let symbol = units.symbols[axis]
            axes.append(ApplyZoomDialog.Axis(
                axis: axis,
                title: zoomRangeLine(axis: axis) ?? labels[axis],
                keepAction: ApplyZoomChoice.initialAxisAction(axis: axis, zoomed: true, simple: .keep, incrementalX: descriptor.partialUpdate, follows: zoomManager.isZoomFollows),
                offersFollow: axis == 0 && descriptor.partialUpdate,
                unitSymbol: symbol.isEmpty ? nil : symbol))
        }
        guard !axes.isEmpty else {
            finishLeavingExclusive()
            return
        }
        let dialog = ApplyZoomDialog(axes: axes, defaultAction: simple)
        dialog.resultDelegate = self
        dialog.onCancel = { [weak self] in
            self?.pendingLeaveCompletion = nil
        }
        dialog.show()
    }

    //The zoomed range of an axis as the dialog shows it: label, from and to in the display unit, formatted like the tic
    //labels (a clock on a time axis showing system time); nil while the axis is not zoomed
    func zoomRangeLine(axis: Int) -> String? {
        guard zoomManager.isZoomed(axis: axis) else { return nil }
        //A following x axis shows the window where it is on screen, not where the zoom state anchors it
        let bounds = dataManager.currentBounds
        let shown = axis == 0 && zoomManager.isZoomFollows ? (min: bounds.min.x, max: bounds.max.x) : zoomManager.zoomRange(axis: axis)
        guard let range = shown, range.min.isFinite, range.max.isFinite, range.min < range.max else { return nil }

        let isLog = axis == 0 ? dataManager.logX : (axis == 1 ? dataManager.logY : descriptor.logZ)
        let isTime = axis == 0 ? descriptor.timeOnX : (axis == 1 && descriptor.timeOnY)
        let grid = graphRenderer.gridView.grid
        let offset = isTime && systemTime ? (axis == 0 ? grid?.systemTimeOffsetX : grid?.systemTimeOffsetY) ?? 0.0 : 0.0
        let units = displayUnits
        let conversion = units.conversions[axis]

        //Tick space, as GraphDataManager.axisGridLines works in it: log axes in log space, a converted axis in its display unit
        func tickSpace(_ v: Double) -> Double {
            guard let conversion = conversion else { return v }
            return isLog ? log(conversion.toDisplay(exp(v))) : conversion.toDisplay(v)
        }
        let tickMin = tickSpace(range.min)
        let tickMax = tickSpace(range.max)
        let ticks = ExperimentGraphUtilities.getTicks(tickMin, max: tickMax, maxTicks: 5, log: isLog, isTime: isTime && conversion == nil, systemTimeOffset: conversion == nil ? offset : 0.0)
        let precision = ticks.map { $0.precision }.max() ?? 0
        let descriptorPrecision = [descriptor.xPrecision, descriptor.yPrecision, descriptor.zPrecision][axis]
        func text(_ v: Double) -> String {
            return GraphGridView.formatTicLabel(isLog ? exp(v) : v, ticPrecision: precision, descriptorPrecision: descriptorPrecision, suppressScientificNotation: descriptor.suppressScientificNotation, isTime: isTime, systemTimeOffset: offset)
        }

        let clock = isTime && offset > 0
        let symbol = units.symbols[axis]
        let suffix = clock || symbol.isEmpty ? "" : " " + symbol
        let label = [descriptor.localizedXLabel, descriptor.localizedYLabel, descriptor.localizedZLabel][axis]
        return String(format: localize("applyZoomRange"), label, text(tickMin) + suffix, text(tickMax) + suffix)
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
