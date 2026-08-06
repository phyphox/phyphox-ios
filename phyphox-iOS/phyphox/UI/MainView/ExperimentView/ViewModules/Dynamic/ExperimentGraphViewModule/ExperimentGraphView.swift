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

    //Data picker state: values written so far, aligned with descriptor.pickOutputs slots.
    private var pickData: [Double?]
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

    var logX, logY, logZ: Bool
    
    var isViewVisible: Bool = true
    
    // MARK: - Initialization
    required init?(descriptor: GraphViewDescriptor, resourceFolder: URL?) {
        self.descriptor = descriptor
        self.timeReference = descriptor.timeReference
        self.systemTime = descriptor.systemTime
        
        self.logX = descriptor.logX
        self.logY = descriptor.logY
        self.logZ = descriptor.logZ

        self.pickData = [Double?](repeating: nil, count: descriptor.pickOutputs.count)

        // Initialize components
        self.graphRenderer = GraphRenderer(descriptor: descriptor)
        self.zoomManager = GraphZoomManager(descriptor: descriptor)
        self.gestureHandler = GraphGestureHandler()
        self.markerSystem = GraphMarkerSystem(descriptor: descriptor, timeReference: timeReference, graphRenderer: graphRenderer)
        self.toolbarManager = GraphToolbarManager()
        self.layoutManager = GraphLayoutManager(descriptor: descriptor, gridView: graphRenderer.gridView, zGridView: graphRenderer.zGridView)
        self.dataManager = GraphDataManager(descriptor: descriptor, timeReference: timeReference)

        super.init(frame: .zero)

        layoutManager.setupSubviews(renderer: graphRenderer, markerSystem: markerSystem)
        addSubview(layoutManager.graphArea)

        setupPicker()
        setupDelegates()
        setupGestures()
        registerForBufferUpdates()
        attachDisplayLink(displayLink)
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
        markerSystem.delegate = self
        toolbarManager.delegate = self
        graphRenderer.gridView.delegate = self
        graphRenderer.zGridView?.delegate = self
    }
    
    private func setupGestures() {
        gestureHandler.setupGestures(on: layoutManager.graphArea, plotView: graphRenderer.plotView)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapp(_:)))
        layoutManager.graphArea.addGestureRecognizer(tapGesture)
        
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
            //Only the plain slots get a button; the cal slot after them is handled through a value prompt.
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
        //Like any user input (and like on Android), a pick triggers an analysis run even while
        //the experiment is paused, so dependent views like a calibrated graph update immediately
        descriptor.pickOutputs[slot]?.buffer.triggerUserInput()
    }

    //The pick buffers can change externally, for example through the analysis or when the data
    //is cleared, so their current state is re-read on every graph update, like on Android. An
    //empty buffer or NaN removes the corresponding annotation.
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
            let logAxis = vertical ? descriptor.logX : descriptor.logY
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
        if resizableState == .normal {
            layoutDelegate?.presentExclusiveLayout(self)
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
        let dialog = ApplyZoomDialog(
            labelX: descriptor.localizedXLabelWithUnit,
            labelY: descriptor.localizedYLabelWithUnit,
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
        layoutManager.updateAxisLabels(systemTime: systemTime, descriptor: descriptor)
        setNeedsLayout()
        dataManager.setNeedsUpdate()
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
                if let toolbar = toolbarManager.toolbar {
                    // Ensure toolbar is added to the view hierarchy
                    if toolbar.superview != self {
                        addSubview(toolbar)
                    }
                    
                    let toolbarSize = toolbar.sizeThatFits(bounds.size)
                    toolbar.frame = CGRect(
                        x: 0,
                        y: bounds.height - toolbarSize.height,
                        width: bounds.width,
                        height: toolbarSize.height
                    )
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
    }
    
    // MARK: - Public Interface
    func clearData() {
        dataManager.clearData()
        graphRenderer.clearGraph()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                graphRenderer.refresh()
                markerSystem.refreshMarkers()
            }
        }
    }
}


extension ExperimentGraphView: GraphGridDelegate {
    //Called by the grid view when the space needed by its tick labels changed, which shifts the
    //plot area: the plot and the marker overlay have to follow, or the data no longer lines up
    //with the grid. The grid recalculates this space in its own layout pass, i.e. after the data
    //update that set the new grid, so without this callback the plot stays one update behind -
    //which goes unnoticed while measuring but sticks when the next update never comes, like
    //after switching to this tab while paused.
    func updatePlotArea() {
        let graphFrame = layoutManager.graphFrame
        if graphRenderer.plotView.frame != graphFrame {
            graphRenderer.updateFrames(graphFrame: graphFrame, zScaleFrame: layoutManager.zScaleFrame)
            markerSystem.updateLayout(graphFrame: graphFrame)
            markerSystem.refreshMarkers()
        }
    }
}

extension ExperimentGraphView: VisibilityControllableViewModule {
    var visibilityBuffer: DataBuffer? { descriptor.visibilityBuffer }
}
