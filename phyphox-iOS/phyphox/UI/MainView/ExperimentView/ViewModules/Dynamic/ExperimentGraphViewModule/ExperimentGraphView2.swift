//
//  ExperimentGraphView2.swift
//  phyphox

//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.

//  Refactored by Gaurav Tripathee on 04.08.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

final class ExperimentGraphView2: UIView, DynamicViewModule, ResizableViewModule, DescriptorBoundViewModule, GraphViewModule, UITabBarDelegate, ZoomableViewModule, ExportingViewModule,  AnalysisLimitedViewModule, DisplayLinkListener {
    
    
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
    private var spectroscopyStatusLabel: UILabel?
    
    var active = false {
        didSet {
            dataManager.active = active
            displayLink.active = active
            if active { dataManager.setNeedsUpdate() }
        }
    }
    
    // MARK: - UI Properties
    let unfoldMoreImageView: UIImageView
    let unfoldLessImageView: UIImageView
    var logX, logY, logZ: Bool
    
    // MARK: - Initialization
    required init?(descriptor: GraphViewDescriptor, resourceFolder: URL?) {
        self.descriptor = descriptor
        self.timeReference = descriptor.timeReference
        self.systemTime = descriptor.systemTime
        
        self.logX = descriptor.logX
        self.logY = descriptor.logY
        self.logZ = descriptor.logZ
        
        //TODO: For now the calibration mode is regarded as spectrosopy mode
        self.isSpectroscopyMode = descriptor.calibrationMode
        
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 25, weight: .regular, scale: .default)
            unfoldLessImageView = UIImageView(image: UIImage(systemName: "arrow.down.right.and.arrow.up.left", withConfiguration: config))
            unfoldMoreImageView = UIImageView(image: UIImage(systemName: "arrow.up.left.and.arrow.down.right", withConfiguration: config))
        } else {
            unfoldLessImageView = UIImageView(image: UIImage(named: "unfold_less"))
            unfoldMoreImageView = UIImageView(image: UIImage(named: "unfold_more"))
        }
        
        // Initialize components
        self.graphRenderer = GraphRenderer(descriptor: descriptor)
        self.zoomManager = GraphZoomManager(descriptor: descriptor)
        self.gestureHandler = GraphGestureHandler()
        self.markerSystem = GraphMarkerSystem(
            descriptor: descriptor,
            timeReference: timeReference,
            graphRenderer: graphRenderer)
        self.toolbarManager = GraphToolbarManager()
        self.spectroscopyManager = SpectroscopyCalibrationManager()
        self.layoutManager = GraphLayoutManager(
            descriptor: descriptor,
            unfoldMoreImageView: unfoldMoreImageView,
            unfoldLessImageView: unfoldLessImageView,
            gridView: graphRenderer.gridView,
            zGridView: graphRenderer.zGridView)
        self.dataManager = GraphDataManager(
            descriptor: descriptor,
            timeReference: timeReference
        )
        
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
    
    // MARK: - Setup
    private func setupDelegates() {
        
        dataManager.delegate = self
        gestureHandler.delegate = self
        zoomManager.delegate = self
        markerSystem.delegate = self
        toolbarManager.delegate = self
        spectroscopyManager.delegate = self
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
    }
        
    
    private func setupSpectroscopyUI(){
        if isSpectroscopyMode {
            toolbarManager.setShouldShowCalibration(true)
            
            spectroscopyStatusLabel = UILabel()
            spectroscopyStatusLabel?.font = UIFont.preferredFont(forTextStyle: .caption1)
            spectroscopyStatusLabel?.textColor = UIColor(named: "textColor")
            spectroscopyStatusLabel?.numberOfLines = 2
            spectroscopyStatusLabel?.textAlignment = .center
            spectroscopyStatusLabel?.isHidden = true
            spectroscopyStatusLabel?.text = localize("spectroscopy_uncalibrated")
            
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
        
        if newState != .exclusive {
            spectroscopyStatusLabel?.isHidden = true
            toolbarManager.toolbar?.removeFromSuperview()
            //TODO: spectroscopyManager.resetCalibration() Should it reset when not in exclusive mode? Come to it after basic functionality is done.
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
                            x: layoutManager.graphFrame.maxX - statusSize.width - 10,
                            y: layoutManager.graphFrame.minY + 10,
                            width: statusSize.width,
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

// MARK: - Delegate Extensions
extension ExperimentGraphView2: GraphDataManagerDelegate {
    func dataManager(_ manager: GraphDataManager, didUpdateData data: GraphDataResult, pauseMarkers: PauseRanges?) {
        
        // Update grid with pause markers
        graphRenderer.gridView.grid = data.grid
        graphRenderer.gridView.pauseMarkers = pauseMarkers
        graphRenderer.zGridView?.grid = data.grid
        
        markerSystem.updateDataContext(dataSets: data.dataSets, bounds: data.bounds, systemTime: systemTime)
        
        // Update renderer with new data
        graphRenderer.updateData(data)
        
        // GridView might have new frame, so need to adapt the plotView with it
        graphRenderer.updateFrames(graphFrame: layoutManager.graphFrame, zScaleFrame: layoutManager.zScaleFrame)
        
        // Update GL graph view
        graphRenderer.plotView.setPoints(
            points2D: data.dataSets.map { $0.points2D },
            points3D: data.dataSets.map { $0.points3D },
            min: data.bounds.min,
            max: data.bounds.max,
            timeReferenceSets: data.dataSets.map { $0.timeReferenceSets }
        )
        
        // Refresh markers
        markerSystem.refreshMarkers()
    }
    
    
    
    func dataManagerDidClearData() {
        graphRenderer.clearGraph()
        markerSystem.clearMarkers()
    }
}


extension ExperimentGraphView2: GraphGestureDelegate {
    func gestureHandler(_ handler: GraphGestureHandler, didTapAt point: CGPoint) {
        let nearestPoint = markerSystem.getIndexOfNearestPoint(at: point, in: dataManager.currentDataSets, bounds: dataManager.currentBounds, frameSize: layoutManager.graphFrame.size)
        
        if toolbarManager.currentMode == .pick {
            markerSystem.handleTap(nearestPoint: nearestPoint)
        } else if toolbarManager.currentMode == .calibrate {
            spectroscopyManager.addCalibrationPoint(pixelIndex: Double(nearestPoint?.index ?? 0), pixelValue: point.y )
        }
    }
    
    func gestureHandler(_ handler: GraphGestureHandler, didPanWithTranslation translation: CGPoint, state: UIGestureRecognizer.State, sender: UIPanGestureRecognizer) {
        if toolbarManager.currentMode == .panZoom {
            zoomManager.applyPanGesture(translation: translation,
                                        bounds: dataManager.currentBounds,
                                        frameSize: layoutManager.graphFrame.size,
                                        state: state)
        } else if toolbarManager.currentMode == .pick {
            markerSystem.handlePanGesture(translation: translation, state: state, at: translation, dataSets: dataManager.currentDataSets, bounds: dataManager.currentBounds, frameSize: layoutManager.graphFrame.size, sender: sender)
        }
    }
    
    func gestureHandler(_ handler: GraphGestureHandler, didPinchWithScale scale: CGFloat, state: UIGestureRecognizer.State, center: CGPoint, touches: (CGPoint, CGPoint)) {
        guard toolbarManager.currentMode == .panZoom else { return }
        zoomManager.applyPinchGesture(scale: scale, center: center, touches: touches, bounds: dataManager.currentBounds, frameSize: layoutManager.graphFrame.size, state: state)
    }
    
    func gestureHandler(_ handler: GraphGestureHandler, didZPanWithTranslation translation: CGPoint, state: UIGestureRecognizer.State) {
        guard toolbarManager.currentMode == .panZoom else { return }
        zoomManager.applyZPanGesture(translation: translation, bounds: dataManager.currentBounds, frameSize: layoutManager.zScaleFrame.size, state: state)
    }
    
    func gestureHandler(_ handler: GraphGestureHandler, didZPinchWithScale scale: CGFloat, state: UIGestureRecognizer.State, center: CGPoint, touches: (CGPoint, CGPoint)) {
        guard toolbarManager.currentMode == .panZoom else { return }
        zoomManager.applyZPinchGesture(scale: scale, center: center, touches: touches, bounds: dataManager.currentBounds, frameSize: layoutManager.zScaleFrame.size, state: state)
    }
}


extension ExperimentGraphView2: GraphZoomDelegate {
    func zoomManagerDidUpdate(_ manager: GraphZoomManager) {
        manager.notifyDataManager(dataManager)
        dataManager.setNeedsUpdate()
    }
}

extension ExperimentGraphView2: GraphMarkerDelegate {
    func markerSystemDidUpdate(_ markerSystem: GraphMarkerSystem) {
        dataManager.setNeedsUpdate()
    }
    
    func markerSystem(_ markerSystem: GraphMarkerSystem, shouldShowLabel text: String?) {
        layoutManager.updateMarkerLabel(text)
    }
    
    func markerSystem(_ markerSystem: GraphMarkerSystem, shouldPositionLabel position: (CGFloat, CGFloat)) {
        // Position marker label based on average marker position
        layoutManager.positionMarkerLabel(averageX: position.0, minY: position.1, viewBounds: bounds.size)
    }
}

extension ExperimentGraphView2: GraphToolbarDelegate {
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

extension ExperimentGraphView2: SpectroscopyCalibrationDelegate {
    func spectroscopyUnCalibrated(_ manager: SpectroscopyCalibrationManager) {
        spectroscopyStatusLabel?.text = ""
        spectroscopyStatusLabel?.isHidden = true
        layoutSubviews()
        markerSystem.clearMarkers()
    }
    
    func spectroscopyCalibrationDidStart(_ manager: SpectroscopyCalibrationManager) {
        spectroscopyStatusLabel?.text = localize("spectroscopy_tap_first_point")
        spectroscopyStatusLabel?.isHidden = false
        layoutSubviews()
        markerSystem.clearMarkers()
    }
    
    func spectroscopyCalibrationDidUpdatePoints(_ manager: SpectroscopyCalibrationManager, points: [(pixelPosition: Double, wavelength: Double)], state: SpectroscopyCalibrationManager.CalibrationState) {
        switch state {
        case .firstPointSelected:
            spectroscopyStatusLabel?.text = localize("spectroscopy_tap_second_point")
        case .secondPointSelected:
            spectroscopyStatusLabel?.text = localize("spectroscopy_calculating")
        default:
            break
        }
        markerSystem.showCalibrationPoints(points)
        
    }
    
    func spectroscopyCalibrationDidComplete(_ manager: SpectroscopyCalibrationManager, slope: Double, intercept: Double) {
        //TODO: calibration system here need to get the calibration info and show this into the status label.
        if let calibrationInfo = manager.getCalibrationInfo() {
                    spectroscopyStatusLabel?.text = calibrationInfo
                }
                
        
        
        //TODO: Transform the data and update graph
        applySpectroscopyCalibration(slope: slope, intercept: intercept)
        
        descriptor.calibrationSlope?.replaceValues([slope])
        descriptor.calibrationIntercept?.replaceValues([intercept])
        
        //TODO: After the transformation is done need to again select the pick mode so that recalibration is possible straigt up
        //TODO: Or can go to normalize graph view and show the result into another calibrated graph.
        toolbarManager.toolbar?.selectedItem = toolbarManager.toolbar?.items?.first { $0.tag == GraphToolbarManager.GraphMode.pick.rawValue }
        toolbarManager.setMode(mode: .pick)
    }
     
    func spectroscopyCalibrationDidReset(_ manager: SpectroscopyCalibrationManager) {
        spectroscopyStatusLabel?.text = localize("spectroscopy_tap_first_point")
        
        markerSystem.clearMarkers()
        
        //TODO: Also might require to revert spectroscopy calibration.
    }
    
    func spectroscopyCalibration(_ manager: SpectroscopyCalibrationManager, shouldPresentDialog dialog: UIAlertController) {
        layoutDelegate?.presentDialog(dialog)
    }
    
    func spectroscopy(_ manager: SpectroscopyCalibrationManager, didFailWithError error: String) {
        spectroscopyStatusLabel?.text = localize("spectroscopy_calibration_failed")
        
        let alert = UIAlertController(title: localize("error"), message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: localize("ok"), style: .default, handler: nil))
        layoutDelegate?.presentDialog(alert)
    }
    
    private func applySpectroscopyCalibration(slope: Double, intercept: Double) {
            // Create calibrated wavelength buffer and update the descriptor
            guard let yBuffer = descriptor.yInputBuffers.first else { return }
            
        }
    
    private func revertSpectroscopyCalibration() {
            // Revert axis labels back to original
            // This would require storing original values
            setNeedsLayout()
            dataManager.setNeedsUpdate()
        }
}


extension ExperimentGraphView2: ApplyZoomDialogResultDelegate {
    func applyZoomDialogResult(modeX: ApplyZoomAction, applyToX: ApplyZoomTarget, modeY: ApplyZoomAction, applyToY: ApplyZoomTarget) {
        zoomManager.previouslyKept = !(modeX == .reset && modeY == .reset)
        layoutDelegate?.restoreLayout()
        
        // Apply zoom settings
        zoomManager.applyZoomSettings(modeX: modeX, applyToX: applyToX, modeY: modeY, applyToY: applyToY)
        
        // Propagate to other graphs if needed
        if applyToX != .this || applyToY != .this {
            propagateZoomToOtherGraphs(modeX: modeX, applyToX: applyToX, modeY: modeY, applyToY: applyToY)
        }
    }
    
    private func propagateZoomToOtherGraphs(modeX: ApplyZoomAction, applyToX: ApplyZoomTarget, modeY: ApplyZoomAction, applyToY: ApplyZoomTarget) {
        let targetX: String?
        let targetY: String?
        
        switch applyToX {
        case .sameUnit:
            targetX = descriptor.localizedXUnit
        case .sameVariable:
            targetX = descriptor.xInputBuffers[0]?.name
        default:
            targetX = nil
        }
        
        switch applyToY {
        case .sameUnit:
            targetY = descriptor.localizedYUnit
        case .sameVariable:
            targetY = descriptor.yInputBuffers[0].name
        default:
            targetY = nil
        }
        
        let zoomBounds = zoomManager.currentZoomBounds
        zoomDelegate?.applyZoom(
            modeX: applyToX == .this ? .none : modeX,
            applyToX: applyToX == .this ? .none : applyToX,
            targetX: targetX,
            modeY: applyToY == .this ? .none : modeY,
            applyToY: applyToY == .this ? .none : applyToY,
            targetY: targetY,
            zoomMin: GraphPoint2D(x: zoomBounds.min.x, y: zoomBounds.min.y),
            zoomMax: GraphPoint2D(x: zoomBounds.max.x, y: zoomBounds.max.y),
            systemTime: systemTime
        )
    }
}

// MARK: - ZoomableViewModule Implementation
extension ExperimentGraphView2 {
    func applyZoom(modeX: ApplyZoomAction, applyToX: ApplyZoomTarget, targetX: String?, modeY: ApplyZoomAction, applyToY: ApplyZoomTarget, targetY: String?, zoomMin: GraphPoint2D<Double>, zoomMax: GraphPoint2D<Double>, systemTime: Bool) {
        
        var applyX = false
        var applyY = false
        
        switch applyToX {
        case .this, .sameAxis:
            applyX = true
        case .sameUnit:
            if targetX == descriptor.localizedXUnit {
                applyX = true
            }
        case .sameVariable:
            if targetX == descriptor.xInputBuffers[0]?.name {
                applyX = true
            }
        case .none:
            break
        }
        
        switch applyToY {
        case .this, .sameAxis:
            applyY = true
        case .sameUnit:
            if targetY == descriptor.localizedYUnit {
                applyY = true
            }
        case .sameVariable:
            if targetY == descriptor.yInputBuffers[0].name {
                applyY = true
            }
        case .none:
            break
        }
        
        if applyX || applyY {
            zoomManager.applyZoomSettings(modeX: applyX ? modeX : .none, applyToX: applyX ? applyToX : .none, modeY: applyY ? modeY : .none, applyToY: applyY ? applyToY : .none)
        }
        
        if (applyX && descriptor.timeOnX) || (applyY && descriptor.timeOnY) {
            self.systemTime = systemTime
        }
    }
}

extension ExperimentGraphView2 {
    
    func exportGraphData() {
        let name = self.descriptor.label
        var data: [(name: String, buffer: DataBuffer)] = []
        for i in 0..<self.descriptor.yInputBuffers.count {
            if let buffer = self.descriptor.xInputBuffers[i] {
                data.append((name: self.descriptor.localizedXLabel + (i > 0 ? " \(i+1)" : "") + (self.descriptor.localizedXUnit != "" ? "(" + self.descriptor.localizedXUnit + ")" : ""), buffer: buffer))
            }
            
            //TODO: Export calibrated wavelength data if available
            
            
            data.append((name: self.descriptor.localizedYLabel + (i > 0 ? " \(i+1)" : "") + (self.descriptor.localizedYUnit != "" ? "(" + self.descriptor.localizedYUnit + ")" : ""), buffer: self.descriptor.yInputBuffers[i]))
            if let buffer = self.descriptor.zInputBuffers[i] {
                data.append((name: self.descriptor.localizedZLabel + (i > 0 ? " \(i+1)" : "") + (self.descriptor.localizedZUnit != "" ? "(" + self.descriptor.localizedZUnit + ")" : ""), buffer: buffer))
            }
        }
        let export = ExperimentExport(sets: [ExperimentExportSet(name: name, data: data)])
        menuController?.menuAlertController?.dismiss(animated: true, completion: {() -> Void in
            self.exportDelegate?.showExport(export, singleSet: true)
            })
    }
}


class GraphDataExporter {
    private let descriptor: GraphViewDescriptor
    
    init(descriptor: GraphViewDescriptor) {
        self.descriptor = descriptor
    }
    
    func createExport() -> ExperimentExport {
        let name = descriptor.label
        var data: [(name: String, buffer: DataBuffer)] = []
        
        for i in 0..<descriptor.yInputBuffers.count {
            if let buffer = descriptor.xInputBuffers[i] {
                let xName = descriptor.localizedXLabel + (i > 0 ? " \(i+1)" : "") +
                (descriptor.localizedXUnit != "" ? "(" + descriptor.localizedXUnit + ")" : "")
                data.append((name: xName, buffer: buffer))
            }
            
            let yName = descriptor.localizedYLabel + (i > 0 ? " \(i+1)" : "") +
            (descriptor.localizedYUnit != "" ? "(" + descriptor.localizedYUnit + ")" : "")
            data.append((name: yName, buffer: descriptor.yInputBuffers[i]))
            
            if let buffer = descriptor.zInputBuffers[i] {
                let zName = descriptor.localizedZLabel + (i > 0 ? " \(i+1)" : "") +
                (descriptor.localizedZUnit != "" ? "(" + descriptor.localizedZUnit + ")" : "")
                data.append((name: zName, buffer: buffer))
            }
        }
        
        return ExperimentExport(sets: [ExperimentExportSet(name: name, data: data)])
    }
}
