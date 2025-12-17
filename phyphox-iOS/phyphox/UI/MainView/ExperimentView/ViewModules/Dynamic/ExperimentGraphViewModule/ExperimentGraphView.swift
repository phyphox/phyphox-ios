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
    let spectroscopyManager: SpectroscopyCalibrationManager
    
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
    
    private var isSpectroscopyMode: Bool = false
    var spectroscopyStatusLabel: UILabel?
    
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
        
        self.isSpectroscopyMode = descriptor.calibrationMode
        
        // Initialize components
        self.graphRenderer = GraphRenderer(descriptor: descriptor)
        self.zoomManager = GraphZoomManager(descriptor: descriptor)
        self.gestureHandler = GraphGestureHandler()
        self.markerSystem = GraphMarkerSystem(descriptor: descriptor, timeReference: timeReference, graphRenderer: graphRenderer)
        self.toolbarManager = GraphToolbarManager()
        self.spectroscopyManager = SpectroscopyCalibrationManager()
        self.layoutManager = GraphLayoutManager(descriptor: descriptor, gridView: graphRenderer.gridView, zGridView: graphRenderer.zGridView)
        self.dataManager = GraphDataManager(descriptor: descriptor, timeReference: timeReference)
        
        super.init(frame: .zero)
        
        layoutManager.setupSubviews(renderer: graphRenderer, markerSystem: markerSystem)
        addSubview(layoutManager.graphArea)
   
        setupSpectroscopyUI()
        setupDelegates()
        setupGestures()
        registerForBufferUpdates()
        attachDisplayLink(displayLink)
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func getSpectroscopyMode() -> Bool {
        return isSpectroscopyMode
    }
    
    // MARK: - Setup
    private func setupDelegates() {
        dataManager.delegate = self
        gestureHandler.delegate = self
        zoomManager.delegate = self
        markerSystem.delegate = self
        toolbarManager.delegate = self
        spectroscopyManager.delegate = self
        layoutManager.delegate = self
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
        
        if(descriptor.calibrationMode){
            if let slope = descriptor.calibrationSlope{
                registerForUpdatesFromBuffer(slope)
            }
            
            if let intercept = descriptor.calibrationIntercept{
                registerForUpdatesFromBuffer(intercept)
            }
        }
        
        if let visibilityBuffer = descriptor.visibilityBuffer {
            registerForUpdatesFromBuffer(visibilityBuffer)
        }
        
    }

    
    private func setupSpectroscopyUI(){
        if isSpectroscopyMode {
            
            toolbarManager.setShouldShowCalibration(true)
                                    
            spectroscopyStatusLabel = layoutManager.createSpectroscopyStatusLabel()
            if let statusLabel = spectroscopyStatusLabel {
                layoutManager.graphArea.addSubview(statusLabel)
            }
        }
    }
    
    // MARK: - DynamicViewModule Protocol
    func setNeedsUpdate() {
        dataManager.setNeedsUpdate()
    }
    
    // MARK: - DisplayLinkListener Protocol
    func display(_ displayLink: DisplayLink) {
        if dataManager.wantsUpdate && !analysisRunning {
            dataManager.performUpdate()
            if let visibilityBuffer = descriptor.visibilityBuffer?.last {
                if(visibilityBuffer <= 0.0 || descriptor.visibilityBuffer?.size == 0){
                    self.isHidden = true
                    (parentViewController() as? ExperimentViewController)?.updateLayoutVisibilityState(view: self, visible: false)
                    isViewVisible = false
                } else {
                    self.isHidden = false
                    (parentViewController() as? ExperimentViewController)?.updateLayoutVisibilityState(view: self, visible: true)
                    isViewVisible = true
                }
            }
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
        
        if newState == .normal {
            if(!spectroscopyManager.getCalibrationPoints().isEmpty){
                toolbarManager.setMode(mode: .calibrate)
            }
            if(toolbarManager.currentMode != .calibrate){
                spectroscopyStatusLabel?.isHidden = true
            }
        }
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
        
        if let statusLabel = spectroscopyStatusLabel, !statusLabel.isHidden {
            let statusSize = statusLabel.sizeThatFits(bounds.size)
                        statusLabel.frame = CGRect(
                            x: layoutManager.graphFrame.minX + 10,
                            y: layoutManager.graphFrame.minY + 10,
                            width: statusSize.width + 50,
                            height: statusSize.height
                        )
        }
        
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
