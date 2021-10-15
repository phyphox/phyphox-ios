//
//  ExperimentGraphView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit

final class ExperimentGraphView: UIView, DynamicViewModule, ResizableViewModule, DescriptorBoundViewModule, GraphViewModule, UITabBarDelegate, ApplyZoomDialogResultDelegate, ApplyZoomDelegate, ZoomableViewModule, ExportingViewModule, UITableViewDataSource, UITableViewDelegate {
    
    let unfoldMoreImageView: UIImageView
    let unfoldLessImageView: UIImageView
    
    private let sideMargins:CGFloat = 10.0
    
    let descriptor: GraphViewDescriptor
    let timeReference: ExperimentTimeReference
    var logX, logY, logZ: Bool
    
    var systemTime: Bool {
        didSet {
            glGraph.systemTime = systemTime
            if descriptor.timeOnX {
                xLabel.text = systemTime ? descriptor.localizedXLabelWithTimezone : descriptor.localizedXLabelWithUnit
            } else if descriptor.timeOnY {
                yLabel.text = systemTime ? descriptor.localizedYLabelWithTimezone : descriptor.localizedYLabelWithUnit
            }
            setNeedsLayout()
            setNeedsUpdate()
        }
    }
    
    var exportDelegate: ExportDelegate? = nil
    var layoutDelegate: ModuleExclusiveLayoutDelegate? = nil
    var zoomDelegate: ApplyZoomDelegate? = nil
    var resizableState: ResizableViewModuleState = .normal

    private let displayLink = DisplayLink(refreshRate: 0)

    private var graphTools: UITabBar?
    enum Mode: Int {
        case pan_zoom = 0, pick, none
    }
    private var mode = Mode.none {
        didSet {
            if let bar = graphTools, let items = bar.items {
                bar.selectedItem = items[mode.rawValue]
            }
        }
    }
    private var graphArea = UIView()
    
    var active = false {
        didSet {
            displayLink.active = active
            if active {
                setNeedsUpdate()
            }
        }
    }

    private let label = UILabel()
    private let xLabel: UILabel
    private let yLabel: UILabel
    private let zLabel: UILabel?
    
    private let glGraph: GLGraphView
    private let gridView: GraphGridView
    private let markerOverlayView: MarkerOverlayView
    
    private let glZScale: GLGraphView?
    private let zGridView: GraphGridView?
    let hasZData: Bool
    let zScaleHeight: CGFloat = 40
    
    private var previouslyKept = false //Keeps track of the last choice of the user, whether he elected to keep is zoom level or reset it when leaving the interactive mode.
    
    //Keeping track of old max/min for extend zoom strategy
    private var historicMinX = +Double.infinity
    private var historicMaxX = -Double.infinity
    private var historicMinY = +Double.infinity
    private var historicMaxY = -Double.infinity
    private var historicMinZ = +Double.infinity
    private var historicMaxZ = -Double.infinity
    
    private var zoomMin: GraphPoint3D<Double>?
    private var zoomMax: GraphPoint3D<Double>?
    private var zoomFollows = false

    var panGestureRecognizer: UIPanGestureRecognizer? = nil
    var pinchGestureRecognizer: UIPinchGestureRecognizer? = nil
    var zPanGestureRecognizer: UIPanGestureRecognizer? = nil
    var zPinchGestureRecognizer: UIPinchGestureRecognizer? = nil
    
    var markers: [(set: Int, index: Int)] = [] {
        didSet {
            refreshMarkers()
        }
    }
    var markerLabel: UILabel? = nil
    var markerLabelFrame: UIView? = nil
    
    var showLinearFit = false
    
    private let queue = DispatchQueue(label: "de.rwth-aachen.phyphox.graphview", qos: .userInitiated, attributes: [], autoreleaseFrequency: .inherit, target: nil)

    private var dataSets: [(bounds: (min: GraphPoint3D<Double>, max: GraphPoint3D<Double>), data2D: [GraphPoint2D<GLfloat>], data3D: [GraphPoint3D<GLfloat>], timeReferenceSets: [TimeReferenceSet])] = []
    
    private func addDataSets(_ sets: [(bounds: (min: GraphPoint3D<Double>, max: GraphPoint3D<Double>), data2D: [GraphPoint2D<GLfloat>], data3D: [GraphPoint3D<GLfloat>], timeReferenceSets: [TimeReferenceSet])]) {
        if descriptor.history > 1 {
            if dataSets.count >= Int(descriptor.history) {
                dataSets.removeFirst()
            }
            dataSets.append(sets[0])
        } else {
            dataSets = sets
        }
    }
    
    private var max: GraphPoint3D<Double> {
        if dataSets.count > 0 {
            var maxX = -Double.infinity
            var maxY = -Double.infinity
            var maxZ = -Double.infinity
            
            for set in dataSets {
                let maxPoint = set.bounds.max
                
                maxX = Swift.max(maxX, maxPoint.x)
                maxY = Swift.max(maxY, maxPoint.y)
                maxZ = Swift.max(maxZ, maxPoint.z)
            }

            return GraphPoint3D(x: maxX, y: maxY, z: maxZ)
        }
        else {
            return dataSets.first?.bounds.max ?? GraphPoint3D.zero
        }
    }
    
    private var min: GraphPoint3D<Double> {
        if dataSets.count > 0{
            var minX = Double.infinity
            var minY = Double.infinity
            var minZ = Double.infinity
            
            for set in dataSets {
                let minPoint = set.bounds.min
                
                minX = Swift.min(minX, minPoint.x)
                minY = Swift.min(minY, minPoint.y)
                minZ = Swift.min(minZ, minPoint.z)
            }

            return GraphPoint3D(x: minX, y: minY, z: minZ)
        }
        else {
            return GraphPoint3D.zero
        }
    }
    
    private var points2D: [[GraphPoint2D<GLfloat>]] {
        return dataSets.map { $0.data2D }
    }
    
    private var points3D: [[GraphPoint3D<GLfloat>]] {
        return dataSets.map { $0.data3D }
    }
    
    private var timeReferenceSets: [[TimeReferenceSet]] {
        return dataSets.map { $0.timeReferenceSets }
    }
    
    required init?(descriptor: GraphViewDescriptor) {
        self.descriptor = descriptor
        
        logX = descriptor.logX
        logY = descriptor.logY
        logZ = descriptor.logZ
        
        glGraph = GLGraphView()
        glGraph.style = descriptor.style
        glGraph.lineWidth = []
        glGraph.lineColor = []
        
        for i in 0..<descriptor.yInputBuffers.count {
            glGraph.lineWidth.append(Float(descriptor.lineWidth[i] * (descriptor.style[i] == .dots ? 4.0 : 2.0)))
            var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
            
            descriptor.color[i].getRed(&r, green: &g, blue: &b, alpha: &a)
            glGraph.lineColor.append(GLcolor(r: Float(r), g: Float(g), b: Float(b), a: Float(a)))
        }
        glGraph.historyLength = descriptor.history
        glGraph.mapWidth = descriptor.mapWidth
        glGraph.colorMap = descriptor.colorMap
        
        hasZData = glGraph.style[0] == .map
        
        gridView = GraphGridView(descriptor: descriptor, isZScale: false)
        gridView.gridInset = CGPoint(x: 2.0, y: 2.0)
        gridView.gridOffset = CGPoint(x: 0.0, y: 0)
        
        markerOverlayView = MarkerOverlayView()
        markerOverlayView.clipsToBounds = true
        
        if hasZData {
            glZScale = GLGraphView()
            glZScale?.style = descriptor.style
            glZScale?.mapWidth = 2
            glZScale?.colorMap = descriptor.colorMap
            
            //We only set some dummy points once to show the gradient.
            //We do not event need to update it when the user scales the z axis as this only changes the tics of the grid view below that is mapped to the same color gradient
            let x0y0z0 = GraphPoint3D<GLfloat>(x: 0.0, y: 0.0, z: 0.0)
            let x1y0z1 = GraphPoint3D<GLfloat>(x: 1.0, y: 0.0, z: 1.0)
            let x0y1z0 = GraphPoint3D<GLfloat>(x: 0.0, y: 1.0, z: 0.0)
            let x1y1z1 = GraphPoint3D<GLfloat>(x: 1.0, y: 1.0, z: 1.0)
            let min = GraphPoint3D<Double>(x: 0.0, y: 0.0, z: 0.0)
            let max = GraphPoint3D<Double>(x: 1.0, y: 1.0, z: 1.0)
            glZScale?.setPoints(points2D: [[]], points3D: [[x0y0z0, x1y0z1, x0y1z0, x1y1z1]], min: min, max: max, timeReferenceSets: [[]])
            
            zGridView = GraphGridView(descriptor: descriptor, isZScale: true)
            zGridView?.gridInset = CGPoint(x: 2.0, y: 2.0)
            zGridView?.gridOffset = CGPoint(x: 0.0, y: 0.0)
        } else {
            glZScale = nil
            zGridView = nil
        }
        
        func makeLabel(_ text: String?) -> UILabel {
            let l = UILabel()
            l.text = text
            
            let defaultFont = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body)
            l.font = defaultFont.withSize(defaultFont.pointSize * 0.8)
            
            return l
        }
        
        label.numberOfLines = 0
        label.text = descriptor.localizedLabel
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = kTextColor
        
        xLabel = makeLabel(descriptor.systemTime ? descriptor.localizedXLabelWithTimezone : descriptor.localizedXLabelWithUnit)
        yLabel = makeLabel(descriptor.systemTime ? descriptor.localizedYLabelWithTimezone : descriptor.localizedYLabelWithUnit)
        xLabel.textColor = kTextColor
        yLabel.textColor = kTextColor
        yLabel.transform = CGAffineTransform(rotationAngle: -CGFloat(Double.pi/2.0))
        
        if hasZData {
            zLabel = makeLabel(descriptor.localizedZLabelWithUnit)
            zLabel?.textColor = kTextColor
        } else {
            zLabel = nil
        }
        
        unfoldLessImageView = UIImageView(image: UIImage(named: "unfold_less"))
        unfoldMoreImageView = UIImageView(image: UIImage(named: "unfold_more"))
        
        timeReference = descriptor.timeReference
        systemTime = descriptor.systemTime
        
        glGraph.timeOnX = descriptor.timeOnX
        glGraph.timeOnY = descriptor.timeOnY
        glGraph.systemTime = systemTime
        glGraph.linearTime = descriptor.linearTime
        
        super.init(frame: .zero)
        
        gridView.delegate = self
        zGridView?.delegate = self
        
        gridView.isUserInteractionEnabled = false
        zGridView?.isUserInteractionEnabled = false
        markerOverlayView.isUserInteractionEnabled = false

        let unfoldRect = CGRect(x: 5, y: 5, width: 20, height: 20)
        unfoldMoreImageView.frame = unfoldRect
        unfoldLessImageView.frame = unfoldRect
        unfoldLessImageView.isHidden = true
        unfoldMoreImageView.isHidden = false
        
        graphArea.addSubview(unfoldMoreImageView)
        graphArea.addSubview(unfoldLessImageView)
        graphArea.addSubview(label)
        graphArea.addSubview(glGraph)
        graphArea.addSubview(gridView)
        graphArea.addSubview(xLabel)
        graphArea.addSubview(yLabel)
        if let glZScale = glZScale, let zGridView = zGridView, let zLabel = zLabel {
            graphArea.addSubview(glZScale)
            graphArea.addSubview(zGridView)
            graphArea.addSubview(zLabel)
        }
        graphArea.addSubview(markerOverlayView)
        
        addSubview(graphArea)

        for i in 0..<descriptor.yInputBuffers.count {
            registerForUpdatesFromBuffer(descriptor.yInputBuffers[i])
            if let xBuffer = descriptor.xInputBuffers[i] {
                registerForUpdatesFromBuffer(xBuffer)
            }
        }

        attachDisplayLink(displayLink)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ExperimentGraphView.tapped(_:)))
        graphArea.addGestureRecognizer(tapGesture)
        
        let plotTapGesture = UITapGestureRecognizer(target: self, action: #selector(ExperimentGraphView.plotTapped(_:)))
        glGraph.addGestureRecognizer(plotTapGesture)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func resizableStateChanged(_ newState: ResizableViewModuleState) {
        if newState == .exclusive {
            unfoldMoreImageView.isHidden = true
            unfoldLessImageView.isHidden = false
            panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(ExperimentGraphView.panned(_:)))
            pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(ExperimentGraphView.pinched(_:)))
            if let gr = panGestureRecognizer {
                glGraph.addGestureRecognizer(gr)
            }
            if let gr = pinchGestureRecognizer {
                glGraph.addGestureRecognizer(gr)
            }
            if let glZScale = glZScale {
                zPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(ExperimentGraphView.zPanned(_:)))
                zPinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(ExperimentGraphView.zPinched(_:)))
                if let gr = zPanGestureRecognizer {
                    glZScale.addGestureRecognizer(gr)
                }
                if let gr = zPinchGestureRecognizer {
                    glZScale.addGestureRecognizer(gr)
                }
            }
        } else {
            unfoldMoreImageView.isHidden = false
            unfoldLessImageView.isHidden = true
            markers = []
            showLinearFit = false
            if let gr = panGestureRecognizer {
                glGraph.removeGestureRecognizer(gr)
            }
            if let gr = pinchGestureRecognizer {
                glGraph.removeGestureRecognizer(gr)
            }
            panGestureRecognizer = nil
            pinchGestureRecognizer = nil
            if let glZScale = glZScale {
                if let gr = zPanGestureRecognizer {
                    glZScale.removeGestureRecognizer(gr)
                }
                if let gr = zPinchGestureRecognizer {
                    glZScale.removeGestureRecognizer(gr)
                }
                zPanGestureRecognizer = nil
                zPinchGestureRecognizer = nil
            }
        }
    }
    
    @objc func tapped(_ sender: UITapGestureRecognizer) {
        if resizableState == .normal {
            layoutDelegate?.presentExclusiveLayout(self)
        } else {
            if (zoomFollows || zoomMax != nil || systemTime) {
                let dialog = ApplyZoomDialog(labelX: descriptor.localizedXLabelWithUnit, labelY: descriptor.localizedYLabelWithUnit, preselectKeep: previouslyKept)
                dialog.resultDelegate = self
                dialog.show()
            } else {
                layoutDelegate?.restoreLayout()
            }
        }
    }
    
    func getIndexOfNearestPoint(at: CGPoint) -> (set: Int, index: Int)? {
        var minDist = CGFloat.infinity
        var minSet = -1
        var minIndex = -1
        
        let searchRange: CGFloat = 30.0
        let searchRange2 = searchRange*searchRange
        
        let rangeMin = self.min
        let rangeMax = self.max
        let minX = CGFloat(rangeMin.x)
        let minY = CGFloat(rangeMin.y)
        let maxX = CGFloat(rangeMax.x)
        let maxY = CGFloat(rangeMax.y)
        let frame = graphFrame
        let w = frame.width
        let h = frame.height
        
        func viewXtoDataX(_ x: CGFloat) -> CGFloat {
            return (maxX-minX)*(x/w) + minX
        }
        
        func viewYtoDataY(_ y: CGFloat) -> CGFloat {
            return maxY - (maxY-minY) * (y/h)
        }
        
        func offsetFromDataTime(v: Double) -> Double {
            if systemTime && !descriptor.linearTime {
                return timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: v))
            } else if !systemTime && descriptor.linearTime {
                return -timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromLinearTime(t: v))
            }
            return 0.0
        }
        
        func offsetFromViewTime(v: Double) -> Double {
            if systemTime && !descriptor.linearTime {
                return timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromGappedExperimentTime(t: v))
            } else if !systemTime && descriptor.linearTime {
                print("Index: \(timeReference.getReferenceIndexFromExperimentTime(t: v)) from \(v)")
                return -timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: v))
            }
            return 0.0
        }
        
        var searchRangeMaxX = Swift.max(viewXtoDataX(at.x + searchRange), viewXtoDataX(at.x - searchRange))
        var searchRangeMinX = Swift.min(viewXtoDataX(at.x + searchRange), viewXtoDataX(at.x - searchRange))
        var searchRangeMaxY = Swift.max(viewYtoDataY(at.y + searchRange), viewYtoDataY(at.y - searchRange))
        var searchRangeMinY = Swift.min(viewYtoDataY(at.y + searchRange), viewYtoDataY(at.y - searchRange))
        
        if descriptor.timeOnX {
            let offset = offsetFromViewTime(v: Double(viewXtoDataX(at.x)))
            searchRangeMinX -= CGFloat(offset)
            searchRangeMaxX -= CGFloat(offset)
        }
        if descriptor.timeOnY {
            let offset = offsetFromViewTime(v: Double(viewYtoDataY(at.y)))
            searchRangeMinY -= CGFloat(offset)
            searchRangeMaxY -= CGFloat(offset)
        }
        
        print("Suche in \(searchRangeMinX) bis \(searchRangeMaxX)")
        
        for (i, dataSet) in dataSets.enumerated() {
            
            let n = hasZData ? dataSet.data3D.count : dataSet.data2D.count
            for j in 0..<n {
                if descriptor.style.count > i && (descriptor.style[i] == .hbars || descriptor.style[i] == .vbars) {
                    if j % 6 != 2 && j % 6 != 3 {
                        continue
                    }
                }
                var x = CGFloat(hasZData ? dataSet.data3D[j].x : dataSet.data2D[j].x)
                var y = CGFloat(hasZData ? dataSet.data3D[j].y : dataSet.data2D[j].y)
                
                if x < searchRangeMinX || x > searchRangeMaxX || y < searchRangeMinY || y > searchRangeMaxY {
                    continue
                }
                
                if descriptor.timeOnX {
                    let offset = offsetFromDataTime(v: Double(x))
                    x += CGFloat(offset)
                }
                if descriptor.timeOnY {
                    let offset = offsetFromDataTime(v: Double(y))
                    y += CGFloat(offset)
                }
                
                let vx = (x - minX) / (maxX-minX) * w
                let vy = (maxY - y) / (maxY-minY) * h
                let dx = vx - at.x
                let dy = vy - at.y
                let d = dx*dx+dy*dy
                
                if (d < searchRange2 && d < minDist) {
                    minDist = d
                    minSet = i
                    minIndex = j
                }
            }
        }
        
        if minSet >= 0 && minIndex >= 0 {
            return (set: minSet, index: minIndex)
        } else {
            return nil
        }
    }
    
    @objc func plotTapped(_ sender: UITapGestureRecognizer) {
        if resizableState == .normal {
            tapped(sender)
        }
        if mode != .pick {
            return
        }
        
        if let point = getIndexOfNearestPoint(at: sender.location(in: glGraph)) {
            markers = [point]
            showLinearFit = false
        } else {
            markers = []
        }
    }
    
    func applyZoomDialogResult(modeX: ApplyZoomAction, applyToX: ApplyZoomTarget, modeY: ApplyZoomAction, applyToY: ApplyZoomTarget) {
        
        previouslyKept = !(modeX == .reset && modeY == .reset)
        
        layoutDelegate?.restoreLayout()
        
        if zoomMin == nil || zoomMax == nil {
            zoomMin = GraphPoint3D(x: min.x, y: min.y, z: min.z)
            zoomMax = GraphPoint3D(x: max.x, y: max.y, z: max.z)
            
            if zoomMin == nil || zoomMax == nil || zoomMin!.x == zoomMax!.x || zoomMin!.y == zoomMax!.y {
                return
            }
        }
        
        applyZoom(modeX: modeX, applyToX: .this, targetX: nil, modeY: modeY, applyToY: .this, targetY: nil, zoomMin: GraphPoint2D(x: zoomMin!.x, y: zoomMin!.y), zoomMax: GraphPoint2D(x: zoomMax!.x, y: zoomMax!.y), systemTime: systemTime)
        if (applyToX != .this || applyToY != .this) {
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

            zoomDelegate?.applyZoom(modeX: applyToX == .this ? .none : modeX, applyToX: applyToX == .this ? .none : applyToX, targetX: targetX, modeY: applyToY == .this ? .none : modeY, applyToY: applyToY == .this ? .none : applyToY, targetY: targetY, zoomMin: GraphPoint2D(x: zoomMin!.x, y: zoomMin!.y), zoomMax: GraphPoint2D(x: zoomMax!.x, y: zoomMax!.y), systemTime: systemTime)
        }
    }
    
    func applyZoom(modeX: ApplyZoomAction, applyToX: ApplyZoomTarget, targetX: String?, modeY: ApplyZoomAction, applyToY: ApplyZoomTarget, targetY: String?, zoomMin: GraphPoint2D<Double>, zoomMax: GraphPoint2D<Double>, systemTime: Bool) {
        
        var applyX = false
        var applyY = false
        
        switch applyToX {
        case .this:
            applyX = true
        case .sameAxis:
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
        case .this:
            applyY = true
        case .sameAxis:
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
        
        if applyX {
            switch modeX {
            case .reset:
                self.zoomMax = GraphPoint3D(x: Double.nan, y: self.zoomMax?.y ?? Double.nan, z: Double.nan)
                self.zoomMin = GraphPoint3D(x: Double.nan, y: self.zoomMin?.y ?? Double.nan, z: Double.nan)
            case .keep:
                self.zoomMax = GraphPoint3D(x: zoomMax.x, y: self.zoomMax?.y ?? Double.nan, z: Double.nan)
                self.zoomMin = GraphPoint3D(x: zoomMin.x, y: self.zoomMin?.y ?? Double.nan, z: Double.nan)
            case .follow:
                self.zoomMax = GraphPoint3D(x: zoomMax.x, y: self.zoomMax?.y ?? Double.nan, z: Double.nan)
                self.zoomMin = GraphPoint3D(x: zoomMin.x, y: self.zoomMin?.y ?? Double.nan, z: Double.nan)
                zoomFollows = true
            case .none:
                break
            }
            if descriptor.timeOnX {
                self.systemTime = systemTime
            }
        }
        
        if applyY {
            switch modeY {
            case .reset:
                self.zoomMax = GraphPoint3D(x: self.zoomMax?.x ?? Double.nan, y: Double.nan, z: Double.nan)
                self.zoomMin = GraphPoint3D(x: self.zoomMin?.x ?? Double.nan, y: Double.nan, z: Double.nan)
            case .keep:
                self.zoomMax = GraphPoint3D(x: self.zoomMax?.x ?? Double.nan, y: zoomMax.y, z: Double.nan)
                self.zoomMin = GraphPoint3D(x: self.zoomMin?.x ?? Double.nan, y: zoomMin.y, z: Double.nan)
            default:
                break
            }
            if descriptor.timeOnY {
                self.systemTime = systemTime
            }
        }
        
        update()
    }
    
    var panStartMin: GraphPoint2D<Double>?
    var panStartMax: GraphPoint2D<Double>?
    
    @objc func panned (_ sender: UIPanGestureRecognizer) {
        if (mode == .pan_zoom) {
            zoomFollows = false
            
            let offset = sender.translation(in: self)
            
            let min = GraphPoint2D(x: self.min.x, y: self.min.y)
            let max = GraphPoint2D(x: self.max.x, y: self.max.y)
            
            if sender.state == .began {
                panStartMin = min
                panStartMax = max
            }
            
            guard let startMin = panStartMin, let startMax = panStartMax else {
                return
            }
            
            let dx = Double(offset.x / glGraph.frame.width) * (max.x - min.x)
            let dy = Double(offset.y / glGraph.frame.height) * (min.y - max.y)
            
            zoomMin = GraphPoint3D(x: startMin.x - dx, y: startMin.y - dy, z: zoomMin?.z ?? Double.nan)
            zoomMax = GraphPoint3D(x: startMax.x - dx, y: startMax.y - dy, z: zoomMax?.z ?? Double.nan)
            
            self.update()
        } else if mode == .pick {
            if sender.state == .began {
                if let point = getIndexOfNearestPoint(at: sender.location(in: glGraph)) {
                    markers = [point]
                    showLinearFit = false
                } else {
                    markers = []
                }
            } else {
                if let point = getIndexOfNearestPoint(at: sender.location(in: glGraph)) {
                    if markers.count > 1 {
                        markers[1] = point
                    } else {
                        markers.append(point)
                    }
                }
            }
        }
    }
    
    var pinchOrigin: GraphPoint2D<Double>?
    var pinchScale: GraphPoint2D<Double>?
    var pinchTouchScale: GraphPoint2D<CGFloat>?
    
    @objc func pinched (_ sender: UIPinchGestureRecognizer) {
        if (mode != .pan_zoom) {
            return
        }
        if sender.numberOfTouches != 2 {
            return
        }
        
        zoomFollows = false
        
        let min = self.min
        let max = self.max
        
        let t1 = sender.location(ofTouch: 0, in: self)
        let t2 = sender.location(ofTouch: 1, in: self)
        
        let centerX = (t1.x + t2.x)/2.0
        let centerY = (t1.y + t2.y)/2.0
        
        if sender.state == .began {
            pinchTouchScale = GraphPoint2D(x: abs(t1.x - t2.x)/sender.scale, y: abs(t1.y - t2.y)/sender.scale)
            pinchScale = GraphPoint2D(x: max.x - min.x, y: max.y - min.y)
            pinchOrigin = GraphPoint2D(x: min.x + Double(centerX-glGraph.frame.minX)/Double(glGraph.frame.width)*pinchScale!.x, y: max.y - Double(centerY-glGraph.frame.minY)/Double(glGraph.frame.height)*pinchScale!.y)
        }
        
        guard let origin = pinchOrigin, let scale = pinchScale, let touchScale = pinchTouchScale else {
            return
        }
        
        let dx = abs(t1.x-t2.x)
        let dy = abs(t1.y-t2.y)
        
        var scaleX: Double
        var scaleY: Double
        
        if touchScale.x / touchScale.y > 0.5 {
            scaleX = Double(touchScale.x / dx) * scale.x
        } else {
            scaleX = scale.x
        }
        
        if touchScale.y / touchScale.x > 0.5 {
            scaleY = Double(touchScale.y / dy) * scale.y
        } else {
            scaleY = scale.y
        }
        
        if scaleX > 20*scale.x {
            scaleX = 20*scale.x
        }
        if scaleY > 20*scale.y {
            scaleY = 20*scale.y
        }
        
        let zoomMinX = origin.x - Double(centerX-glGraph.frame.minX)/Double(glGraph.frame.width) * scaleX
        let zoomMaxX = zoomMinX + scaleX
        let zoomMaxY = origin.y + Double(centerY-glGraph.frame.minY)/Double(glGraph.frame.height) * scaleY
        let zoomMinY = zoomMaxY - scaleY
        zoomMin = GraphPoint3D(x: zoomMinX, y: zoomMinY, z: zoomMin?.z ?? Double.nan)
        zoomMax = GraphPoint3D(x: zoomMaxX, y: zoomMaxY, z: zoomMax?.z ?? Double.nan)
        
        self.update()
    }
    
    var zPanStartMin: Double?
    var zPanStartMax: Double?
    
    @objc func zPanned (_ sender: UIPanGestureRecognizer) {
        if (mode != .pan_zoom) {
            return
        }
        
        let offset = sender.translation(in: self)
        
        let min = self.min.z
        let max = self.max.z
        
        if sender.state == .began {
            zPanStartMin = min
            zPanStartMax = max
        }
        
        guard let startMin = zPanStartMin, let startMax = zPanStartMax else {
            return
        }
        
        let dz = Double(offset.x / glZScale!.frame.width) * (max - min)
        
        zoomMin = GraphPoint3D(x: zoomMin?.x ?? Double.nan, y: zoomMin?.y ?? Double.nan, z: startMin - dz)
        zoomMax = GraphPoint3D(x: zoomMax?.x ?? Double.nan, y: zoomMax?.y ?? Double.nan, z: startMax - dz)
        
        self.update()
    }
    
    var zPinchOrigin: Double?
    var zPinchScale: Double?
    var zPinchTouchScale: CGFloat?
    
    @objc func zPinched (_ sender: UIPinchGestureRecognizer) {
        if (mode != .pan_zoom) {
            return
        }
        if sender.numberOfTouches != 2 {
            return
        }
        
        let min = self.min.z
        let max = self.max.z
        
        let t1 = sender.location(ofTouch: 0, in: self)
        let t2 = sender.location(ofTouch: 1, in: self)
        
        let centerX = (t1.x + t2.x)/2.0
        
        if sender.state == .began {
            zPinchTouchScale = abs(t1.x - t2.x)/sender.scale
            zPinchScale = max - min
            zPinchOrigin = min + Double(centerX-glZScale!.frame.minX)/Double(glZScale!.frame.width)*zPinchScale!
        }
        
        guard let origin = zPinchOrigin, let scale = zPinchScale, let touchScale = zPinchTouchScale else {
            return
        }
        
        let dz = abs(t1.x-t2.x)
        var scaleZ = Double(touchScale / dz) * scale
        
        if scaleZ > 20*scale {
            scaleZ = 20*scale
        }
        
        let zoomMinZ = origin - Double(centerX-glZScale!.frame.minX)/Double(glZScale!.frame.width) * scaleZ
        let zoomMaxZ = zoomMinZ + scaleZ
        
        zoomMin = GraphPoint3D(x: zoomMin?.x ?? Double.nan, y: zoomMin?.y ?? Double.nan, z: zoomMinZ)
        zoomMax = GraphPoint3D(x: zoomMax?.x ?? Double.nan, y: zoomMax?.y ?? Double.nan, z: zoomMaxZ)
        
        self.update()
    }
    
    //MARK - Graph
    
    private var lastIndexXArray: [Double]?
    private var lastCount: Int?

    private func runUpdate() {
        var xValues: [[Double]] = []
        var yValues: [[Double]] = []
        var zValues: [[Double]] = []
        var count: [Int] = []
        var points2D: [[GraphPoint2D<GLfloat>]] = []
        var points3D: [[GraphPoint3D<GLfloat>]] = []

        for i in 0..<descriptor.yInputBuffers.count {
            yValues.append(descriptor.yInputBuffers[i].toArray())

            count.append(yValues[i].count)

            if count[i] < 1 {
                xValues.append([])
                yValues.append([])
                zValues.append([])
                points2D.append([])
                points3D.append([])
                continue
            }
            
            if let xBuf = descriptor.xInputBuffers[i] {
                xValues.append(xBuf.toArray())
            }
            else {
                var xC = 0

                if lastIndexXArray != nil {
                    xC = lastIndexXArray!.count
                }

                let delta = count[i]-xC

                if delta > 0 && lastIndexXArray == nil {
                    lastIndexXArray = []
                }

                for i in xC..<count[i] {
                    lastIndexXArray!.append(Double(i))
                }

                if lastIndexXArray == nil {
                    mainThread {
                        self.clearGraph()
                    }
                    return
                }

                xValues.append(lastIndexXArray!)
            }
            
            if let zBuf = descriptor.zInputBuffers[i] {
                zValues.append(zBuf.toArray())
            } else {
                zValues.append([])
            }

            count[i] = Swift.min(xValues[i].count, yValues[i].count)
            if descriptor.style[i] == .map {
                count[i] = Swift.min(count[i], zValues[i].count)
            }

            points2D.append([])
            points3D.append([])
            
            if count[i] < 1 {
                continue
            }
            
            let styleCountFactor: Int
            switch descriptor.style[i] {
                case .vbars: styleCountFactor = 6
                case .hbars: styleCountFactor = 6
                default: styleCountFactor = 1
            }
            if descriptor.style[i] == .map {
                points3D[i].reserveCapacity(count[i] * styleCountFactor)
            } else {
                points2D[i].reserveCapacity(count[i] * styleCountFactor)
            }
        }
        
        if count.reduce(0, Swift.max) < 1 {
            mainThread {
                self.clearGraph()
            }
            return
        }

        var minX = Double.infinity
        var maxX = -Double.infinity

        var minY = Double.infinity
        var maxY = -Double.infinity
        
        var minZ = Double.infinity
        var maxZ = -Double.infinity

        var xMinStrict = descriptor.scaleMinX == .fixed
        var xMaxStrict = descriptor.scaleMaxX == .fixed
        var yMinStrict = descriptor.scaleMinY == .fixed
        var yMaxStrict = descriptor.scaleMaxY == .fixed
        var zMinStrict = descriptor.scaleMinZ == .fixed
        var zMaxStrict = descriptor.scaleMaxZ == .fixed

        if xMinStrict {
            minX = Double(descriptor.minX)
        }
        if xMaxStrict {
            maxX = Double(descriptor.maxX)
        }
        if yMinStrict {
            minY = Double(descriptor.minY)
        }
        if yMaxStrict {
            maxY = Double(descriptor.maxY)
        }
        if zMinStrict {
            minZ = Double(descriptor.minZ)
        }
        if zMaxStrict {
            maxZ = Double(descriptor.maxZ)
        }
        
        if let zMin = zoomMin, let zMax = zoomMax {
            if zMin.x.isFinite && zMax.x.isFinite && zMin.x < zMax.x {
                minX = zMin.x
                maxX = zMax.x
                xMinStrict = true
                xMaxStrict = true
            }
                
            if zMin.y.isFinite && zMax.y.isFinite && zMin.y < zMax.y {
                minY = zMin.y
                maxY = zMax.y
                yMinStrict = true
                yMaxStrict = true
            }
            
            if zMin.z.isFinite && zMax.z.isFinite && zMin.z < zMax.z {
                minZ = zMin.z
                maxZ = zMax.z
                zMinStrict = true
                zMaxStrict = true
            }
        }

        var dataSets: [(bounds: (min: GraphPoint3D<Double>, max: GraphPoint3D<Double>), data2D: [GraphPoint2D<GLfloat>], data3D: [GraphPoint3D<GLfloat>], timeReferenceSets: [TimeReferenceSet])] = []
        for i in 0..<count.count {
            var xOrderOK = true
            var lastX = -Double.infinity
            var lastY = Double.nan
            
            var timeReferenceSets = [TimeReferenceSet]()
            var lastReferenceIndex = -1
            var lastChange = 0
            
            for j in 0..<count[i] {
                let rawX = xValues[i][j]
                let rawY = yValues[i][j]
                let rawZ = zValues[i].count > j ? zValues[i][j] : Double.nan

                if descriptor.timeOnX || descriptor.timeOnY {
                    let t = descriptor.timeOnX ? rawX : rawY
                    let referenceIndex = descriptor.linearTime ? timeReference.getReferenceIndexFromLinearTime(t: t) : timeReference.getReferenceIndexFromExperimentTime(t: t)
                    if lastReferenceIndex < 0 {
                        lastReferenceIndex = referenceIndex
                    } else if lastReferenceIndex != referenceIndex {
                        timeReferenceSets.append(TimeReferenceSet(index: lastChange, count: j-lastChange, referenceIndex: lastReferenceIndex, experimentTime: timeReference.getExperimentTimeReferenceByIndex(i: lastReferenceIndex), systemTime: timeReference.getSystemTimeReferenceByIndex(i: lastReferenceIndex), totalPauseGap: timeReference.getTotalGapByIndex(i: lastReferenceIndex), isPaused: timeReference.getPausedByIndex(i: lastReferenceIndex)))
                        lastChange = j
                        lastReferenceIndex = referenceIndex
                    }
                }
                
                let x = (logX ? log(rawX) : rawX)
                let y = (logY ? log(rawY) : rawY)
                let z = (logZ ? log(rawZ) : rawZ)
                
                if x.isFinite && x < lastX {
                    xOrderOK = false
                }
                    
                if x.isFinite && x < minX && !xMinStrict {
                    minX = x
                    if minX < historicMinX {
                        historicMinX = minX
                    } else if descriptor.scaleMinX == .extend {
                        minX = historicMinX
                    }
                }

                if x.isFinite && x > maxX {
                    if !xMaxStrict {
                        maxX = x
                        if maxX > historicMinX {
                            historicMaxX = maxX
                        } else if descriptor.scaleMaxX == .extend {
                            maxX = historicMaxX
                        }
                    } else if zoomFollows && zoomMin != nil && zoomMax != nil && zoomMin!.x.isFinite && zoomMax!.x.isFinite {
                        let w = zoomMax!.x - zoomMin!.x
                        zoomMin = GraphPoint3D(x: x - w, y: zoomMin!.y, z: zoomMin!.z)
                        zoomMax = GraphPoint3D(x: x, y: zoomMax!.y, z: zoomMax!.z)
                        minX = zoomMin!.x
                        maxX = zoomMax!.x
                    }
                }

                if y.isFinite && y < minY && !yMinStrict {
                    minY = y
                    if minY < historicMinY {
                        historicMinY = minY
                    } else if descriptor.scaleMinY == .extend {
                        minY = historicMinY
                    }
                }

                if y.isFinite && y > maxY && !yMaxStrict {
                    maxY = y
                    if maxY > historicMaxY {
                        historicMaxY = maxY
                    } else if descriptor.scaleMaxY == .extend {
                        maxY = historicMaxY
                    }
                }
                if z.isFinite && z < minZ && !zMinStrict {
                    minZ = z
                    if minZ < historicMinZ {
                        historicMinZ = minZ
                    } else if descriptor.scaleMinZ == .extend {
                        minZ = historicMinZ
                    }
                }
                
                if z.isFinite && z > maxZ && !zMaxStrict {
                    maxZ = z
                    if maxZ > historicMaxZ {
                        historicMaxZ = maxZ
                    } else if descriptor.scaleMaxZ == .extend {
                        maxZ = historicMaxZ
                    }
                }

                switch descriptor.style[i] {
                case .hbars:
                    if lastX.isFinite && lastY.isFinite {
                        let off = (y-lastY)*(1.0-Double(descriptor.lineWidth[i]))/2.0
                        let yOff = y-off
                        let lastYOff = lastY+off
                        points2D[i].append(GraphPoint2D(x: GLfloat(0.0), y: GLfloat(lastYOff)))
                        points2D[i].append(GraphPoint2D(x: GLfloat(0.0), y: GLfloat(yOff)))
                        points2D[i].append(GraphPoint2D(x: GLfloat(lastX), y: GLfloat(lastYOff)))
                        points2D[i].append(GraphPoint2D(x: GLfloat(lastX), y: GLfloat(yOff)))
                        points2D[i].append(GraphPoint2D(x: GLfloat(lastX), y: GLfloat(lastYOff)))
                        points2D[i].append(GraphPoint2D(x: GLfloat(0.0), y: GLfloat(yOff)))
                    }
                case .vbars:
                    if lastX.isFinite && lastY.isFinite {
                        let off = (x-lastX)*(1.0-Double(descriptor.lineWidth[i]))/2.0
                        let xOff = x-off
                        let lastXOff = lastX+off
                        points2D[i].append(GraphPoint2D(x: GLfloat(lastXOff), y: GLfloat(0.0)))
                        points2D[i].append(GraphPoint2D(x: GLfloat(xOff), y: GLfloat(0.0)))
                        points2D[i].append(GraphPoint2D(x: GLfloat(lastXOff), y: GLfloat(lastY)))
                        points2D[i].append(GraphPoint2D(x: GLfloat(xOff), y: GLfloat(lastY)))
                        points2D[i].append(GraphPoint2D(x: GLfloat(lastXOff), y: GLfloat(lastY)))
                        points2D[i].append(GraphPoint2D(x: GLfloat(xOff), y: GLfloat(0.0)))
                    }
                case .map:
                    points3D[i].append(GraphPoint3D(x: GLfloat(x), y: GLfloat(y), z: GLfloat(z)))
                    //Note: The only difference is that we are storing 3D data. To actually render this as a map, we will use an index buffer to create the corresponding triangles. Also, it should be mentioned, that we do not use points3D for all the other graphs as storing z = NaN for each point would lead to excessive memory waste.
                default:
                    if !(x.isFinite && y.isFinite) {
                        points2D[i].append(GraphPoint2D(x: GLfloat.nan, y: GLfloat.nan))
                    } else {
                        points2D[i].append(GraphPoint2D(x: GLfloat(x), y: GLfloat(y)))
                    }
                }
                
                lastX = x
                lastY = y
            }
            
            if descriptor.timeOnX || descriptor.timeOnY {
                if lastReferenceIndex < 0 {
                    lastReferenceIndex = 0
                }
                timeReferenceSets.append(TimeReferenceSet(index: lastChange, count: count[i]-lastChange, referenceIndex: lastReferenceIndex, experimentTime: timeReference.getExperimentTimeReferenceByIndex(i: lastReferenceIndex), systemTime: timeReference.getSystemTimeReferenceByIndex(i: lastReferenceIndex), totalPauseGap: timeReference.getTotalGapByIndex(i: lastReferenceIndex), isPaused: timeReference.getPausedByIndex(i: lastReferenceIndex)))
            }

            if !xOrderOK && descriptor.style[i] != .map {
                print("x values are not ordered!")
            }
            
            dataSets.append((bounds: (min: .zero, max: .zero), data2D: points2D[i], data3D: points3D[i], timeReferenceSets: timeReferenceSets))
        }
        
        if systemTime && !descriptor.linearTime && descriptor.timeOnX && !xMinStrict && !xMaxStrict && !hasZData {
            minX += timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: minX))
            maxX += timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: maxX))
        } else if !systemTime && descriptor.linearTime && descriptor.timeOnX && !xMinStrict && !xMaxStrict && !hasZData {
            minX -= timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromLinearTime(t: minX))
            maxX -= timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromLinearTime(t: maxX))
        } else if !logX && !xMinStrict && !xMaxStrict && !hasZData && !descriptor.timeOnX {
            let extraX = (maxX-minX)*0.05;
            maxX += extraX
            minX -= extraX
        }
        
        if systemTime && !descriptor.linearTime && descriptor.timeOnY && !yMinStrict && !yMaxStrict && !hasZData {
            minY += timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: minY))
            maxY += timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: maxY))
        } else if !systemTime && descriptor.linearTime && descriptor.timeOnY && !yMinStrict && !yMaxStrict && !hasZData {
            minY -= timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: minY))
            maxY -= timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: maxY))
        } else if !logY && !yMinStrict && !yMaxStrict && !hasZData && !descriptor.timeOnY {
            let extraY = (maxY-minY)*0.05;
            maxY += extraY
            minY -= extraY
        }
        
        if descriptor.timeOnX && !descriptor.linearTime && !xMinStrict && !xMaxStrict && !hasZData {
            minX = Swift.min(minX, timeReference.getExperimentTimeReferenceByIndex(i: 0))
        }

        
        for i in 0..<dataSets.count {
            dataSets[i].bounds = (min: GraphPoint3D(x: minX, y: minY, z: minZ), max: GraphPoint3D(x: maxX, y: maxY, z: maxZ))
        }

        addDataSets(dataSets)

        let grid = generateGrid(logX: logX, logY: logY, logZ: logZ)
        let pauseMarkers = generatePauseMarkers()
        
        let finalPoints2D = self.points2D
        let finalPoints3D = self.points3D
        let finalTimeReferenceSets = self.timeReferenceSets

        let min = self.min
        let max = self.max

        mainThread {
            self.gridView.grid = grid
            self.gridView.pauseMarkers = pauseMarkers
            self.zGridView?.grid = grid
            self.glGraph.setPoints(points2D: finalPoints2D, points3D: finalPoints3D, min: min, max: max, timeReferenceSets: finalTimeReferenceSets)
            self.refreshMarkers()
        }
    }

    private func setMarkerLabel(_ text: String?) {
        if let text = text {
            if markerLabel == nil {
                markerLabel = UILabel()
                markerLabel?.textColor = UIColor.black
                markerLabel?.numberOfLines = 0
                markerLabelFrame = UIView()
                markerLabelFrame?.backgroundColor = UIColor(white: 1.0, alpha: 0.8)
                markerLabelFrame?.layer.cornerRadius = 5.0
                markerLabelFrame?.layer.masksToBounds = true
                markerLabelFrame?.addSubview(markerLabel!)
                markerLabelFrame?.isUserInteractionEnabled = false
                addSubview(markerLabelFrame!)
            }
            
            markerLabel?.text = text
            let minSize = markerLabel!.sizeThatFits(bounds.size)
            markerLabelFrame?.frame = CGRect(x: 0.0, y: 0.0, width: minSize.width + 20.0, height: minSize.height + 20.0)
            markerLabel?.frame = CGRect(x: 10.0, y: 10.0, width: minSize.width, height: minSize.height)
        } else if markerLabel != nil {
            markerLabel!.removeFromSuperview()
            markerLabelFrame!.removeFromSuperview()
            markerLabel = nil
            markerLabelFrame = nil
        }
    }
    
    private func refreshMarkers() {
        var relativeCoordinates: [(CGFloat, CGFloat)] = []
        
        let min = self.min
        let max = self.max
        
        var xlist: [GLfloat] = []
        var ylist: [GLfloat] = []
        var zlist: [GLfloat] = []
        var avgRX = CGFloat(0.0)
        var minRY = CGFloat.infinity
        var n = 0
        
        func appendMarker(_ x: GLfloat, _ y: GLfloat, _ z: GLfloat) {
            let offsetX: Double
            let offsetY: Double
            if descriptor.timeOnX && systemTime && !descriptor.linearTime {
                offsetX = timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: Double(x)))
            } else if descriptor.timeOnX && !systemTime && descriptor.linearTime {
                offsetX = -timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromLinearTime(t: Double(x)))
            } else {
                offsetX = 0.0
            }
            if descriptor.timeOnY && systemTime && !descriptor.linearTime {
                offsetY = timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: Double(y)))
            } else if descriptor.timeOnY && !systemTime && descriptor.linearTime {
                offsetY = -timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromLinearTime(t: Double(y)))
            } else {
                offsetY = 0.0
            }
            let rx = CGFloat((Double(x) + offsetX - min.x) / (max.x-min.x))
            let ry = CGFloat((max.y - Double(y) - offsetY) / (max.y-min.y))
            
            xlist.append(x)
            ylist.append(y)
            zlist.append(z)
            
            avgRX += rx
            n += 1
            if ry < minRY {
                minRY = ry
            }
            
            relativeCoordinates.append((rx, ry))
        }
        
        for marker in markers {
            if marker.set < dataSets.count {
                let dataSet = dataSets[marker.set]
                
                let x: GLfloat, y: GLfloat, z: GLfloat
                if marker.index < dataSet.data2D.count {
                    x = dataSet.data2D[marker.index].x
                    y = dataSet.data2D[marker.index].y
                    z = GLfloat.nan
                } else if marker.index < dataSet.data3D.count {
                    x = dataSet.data3D[marker.index].x
                    y = dataSet.data3D[marker.index].y
                    z = dataSet.data3D[marker.index].z
                } else {
                    continue
                }
                
                appendMarker(x, y, z)
            }
        }
        
        if n == 1 {
            self.markerOverlayView.showMarkers = true
            self.markerOverlayView.markers = relativeCoordinates
            
            var labelText = localize("graph_point_label")
            labelText += "\n    \(logX ? exp(xlist[0]) : xlist[0])" + (descriptor.localizedXUnit != "" ? " " + descriptor.localizedXUnit : "")
            labelText += "\n    \(logY ? exp(ylist[0]) : ylist[0])" + (descriptor.localizedYUnit != "" ? " " + descriptor.localizedYUnit : "")
            if hasZData {
                labelText += "\n    \(logZ ? exp(zlist[0]) : zlist[0])" + (descriptor.localizedZUnit != "" ? " " + descriptor.localizedZUnit : "")
            }
            setMarkerLabel(labelText)
        } else if n == 2 {
            self.markerOverlayView.showMarkers = true
            self.markerOverlayView.markers = relativeCoordinates
            
            var labelText = localize("graph_difference_label")
            labelText += "\n    \(abs((logX ? exp(xlist[0]) : xlist[0]) - (logX ? exp(xlist[1]) : xlist[1])))" + (descriptor.localizedXUnit != "" ? " " + descriptor.localizedXUnit : "")
            labelText += "\n    \(abs((logY ? exp(ylist[0]) : ylist[0]) - (logY ? exp(ylist[1]) : ylist[1])))" + (descriptor.localizedYUnit != "" ? " " + descriptor.localizedYUnit : "")
            if hasZData {
                labelText += "\n    \(abs((logZ ? exp(zlist[0]) : zlist[0]) - (logZ ? exp(zlist[1]) : zlist[1])))" + (descriptor.localizedZUnit != "" ? " " + descriptor.localizedZUnit : "")
            }
            labelText += "\n" + localize("graph_slope_label")
            labelText += "\n    \(((logY ? exp(ylist[0]) : ylist[0]) - (logY ? exp(ylist[1]) : ylist[1]))/((logX ? exp(xlist[0]) : xlist[0]) - (logX ? exp(xlist[1]) : xlist[1]))) " + descriptor.localizedYXUnit
            setMarkerLabel(labelText)
        } else if showLinearFit {
            if let dataSet = dataSets.first, dataSet.data2D.count >= 2 {
                let a: GLfloat, b: GLfloat
                (a, b) = calculateLinearRegression(dataSet.data2D)
                
                let x1 = GLfloat(min.x)
                let y1 = a * GLfloat(min.x) + b
                appendMarker(x1, y1, GLfloat.nan)
                let x2 = GLfloat(max.x)
                let y2 = a * GLfloat(max.x) + b
                appendMarker(x2, y2, GLfloat.nan)
                
                self.markerOverlayView.showMarkers = false
                self.markerOverlayView.markers = relativeCoordinates
                
                var labelText = localize("graph_fit_label")
                labelText += "\na = \(a) " + descriptor.localizedYXUnit
                labelText += "\nb = \(b)" + (descriptor.localizedYUnit != "" ? " " + descriptor.localizedYUnit : "")
                setMarkerLabel(labelText)
            } else {
                setMarkerLabel(nil)
                self.markerOverlayView.markers = []
            }
        } else {
            setMarkerLabel(nil)
            self.markerOverlayView.markers = []
        }
        
        if let markerLabelFrame = markerLabelFrame, n > 0 {
            avgRX /= CGFloat(n)
            
            let w = markerLabelFrame.frame.width
            let h = markerLabelFrame.frame.height
            
            let frame = glGraph.frame
            let x = Swift.min(Swift.max(frame.minX + avgRX * frame.width - 0.5*w, 0), bounds.width - w)
            let y = Swift.min(Swift.max(frame.minY + minRY * frame.height - h - 15.0, 0), bounds.height - h)
            
            markerLabelFrame.frame = CGRect(x: x, y: y, width: w, height: h)
        }
    }
    
    private func calculateLinearRegression(_ data: [GraphPoint2D<GLfloat>]) -> (GLfloat, GLfloat) {
        var sumX:GLfloat = 0.0
        var sumX2:GLfloat = 0.0
        var sumY:GLfloat = 0.0
        var sumY2:GLfloat = 0.0
        var sumXY:GLfloat = 0.0
        
        for point in data {
            sumX += point.x
            sumX2 += point.x*point.x
            sumY += point.y
            sumY2 += point.y*point.y
            sumXY += point.x*point.y
        }
        
        let norm = GLfloat(data.count) * sumX2 - sumX*sumX;
        guard norm != 0 else {
            return (GLfloat.nan, GLfloat.nan);
        }
        
        let a = (GLfloat(data.count) * sumXY  -  sumX * sumY) / norm;
        let b = (sumY * sumX2  -  sumX * sumXY) / norm;
        
        return (a, b)
    }
    
    private func systemTimeOffset(timeOnAxis: Bool) -> Double {
        if let first = timeReference.timeMappings.first, systemTime && timeOnAxis {
            return first.systemTime.timeIntervalSince1970 - first.experimentTime
        }
        return 0.0
    }
    
    private func generateGrid(logX: Bool, logY: Bool, logZ: Bool) -> GraphGrid {
        let min = self.min
        let max = self.max

        let minX = min.x
        let maxX = max.x

        let minY = min.y
        let maxY = max.y
        
        let minZ = min.z
        let maxZ = max.z

        let xRange = maxX - minX
        let yRange = maxY - minY
        let zRange = maxZ - minZ

        let xTicks = ExperimentGraphUtilities.getTicks(minX, max: maxX, maxTicks: descriptor.timeOnX && systemTime ? 4 : 5, log: logX, isTime: descriptor.timeOnX, systemTimeOffset: systemTimeOffset(timeOnAxis: descriptor.timeOnX))
        let yTicks = ExperimentGraphUtilities.getTicks(minY, max: maxY, maxTicks: 5, log: logY, isTime: descriptor.timeOnY, systemTimeOffset: systemTimeOffset(timeOnAxis: descriptor.timeOnY))
        let zTicks = ExperimentGraphUtilities.getTicks(minZ, max: maxZ, maxTicks: 5, log: logZ, isTime: false, systemTimeOffset: 0.0)

        let mappedXTicks = xTicks.map({ (val) -> GraphGridLine in
            return GraphGridLine(absoluteValue: val, relativeValue: CGFloat(((logX ? log(val) : val) - minX) / xRange))
        })

        let mappedYTicks = yTicks.map({ (val) -> GraphGridLine in
            return GraphGridLine(absoluteValue: val, relativeValue: CGFloat(((logY ? log(val) : val) - minY) / yRange))
        })
        
        let mappedZTicks = zTicks.map({ (val) -> GraphGridLine in
            return GraphGridLine(absoluteValue: val, relativeValue: CGFloat(((logZ ? log(val) : val) - minZ) / zRange))
        })

        return GraphGrid(xGridLines: mappedXTicks, yGridLines: mappedYTicks, zGridLines: mappedZTicks, systemTimeOffsetX: systemTimeOffset(timeOnAxis: descriptor.timeOnX), systemTimeOffsetY: systemTimeOffset(timeOnAxis: descriptor.timeOnY))
    }
    
    func generatePauseMarkers() -> PauseRanges {
        let min = self.min
        let max = self.max

        let minX = min.x
        let maxX = max.x

        let minY = min.y
        let maxY = max.y
        
        let xRange = maxX - minX
        let yRange = maxY - minY
        
        if descriptor.timeOnX {
            if xRange == 0 {
                return PauseRanges(xPauseRanges: [], yPauseRanges: [])
            }
            var pauseRanges: [PauseRange] = []
            var rangeStart: CGFloat? = nil
            for i in 0..<timeReference.timeMappings.count {
                let t = timeReference.getExperimentTimeReferenceByIndex(i: i) + (systemTime ? timeReference.getTotalGapByIndex(i: i) : 0.0)
                let relativeT = CGFloat((t - minX) / xRange)
                if t < minX || t > maxX {
                    continue
                }
                if timeReference.timeMappings[i].event == .PAUSE {
                    rangeStart = relativeT
                } else {
                    pauseRanges.append(PauseRange(relativeBegin: rangeStart ?? 0.0, relativeEnd: relativeT))
                    rangeStart = nil
                }
            }
            if let openEnded = rangeStart {
                pauseRanges.append(PauseRange(relativeBegin: CGFloat(openEnded), relativeEnd: 1.0))
            }
            return PauseRanges(xPauseRanges: pauseRanges, yPauseRanges: [])
        } else if descriptor.timeOnY {
            if yRange == 0 {
                return PauseRanges(xPauseRanges: [], yPauseRanges: [])
            }
            var pauseRanges: [PauseRange] = []
            var rangeStart: CGFloat? = nil
            for i in 0..<timeReference.timeMappings.count {
                let t = timeReference.getExperimentTimeReferenceByIndex(i: i) + (systemTime ? timeReference.getTotalGapByIndex(i: i) : 0.0)
                let relativeT = CGFloat((t - minY) / yRange)
                if t < minY || t > maxY {
                    continue
                }
                if timeReference.timeMappings[i].event == .START {
                    rangeStart = relativeT
                } else {
                    pauseRanges.append(PauseRange(relativeBegin: rangeStart ?? 0.0, relativeEnd: relativeT))
                    rangeStart = nil
                }
            }
            if let openEnded = rangeStart {
                pauseRanges.append(PauseRange(relativeBegin: CGFloat(openEnded), relativeEnd: 1.0))
            }
            return PauseRanges(xPauseRanges: [], yPauseRanges: pauseRanges)
        } else {
            return PauseRanges(xPauseRanges: [], yPauseRanges: [])
        }
    }

    private var wantsUpdate = false

    func setNeedsUpdate() {
        wantsUpdate = true
    }

    private var busy = false

    private func update() {
        guard !busy, superview != nil && window != nil else { return }

        busy = true
        wantsUpdate = false

        queue.async { [weak self] in
            autoreleasepool {
                self?.runUpdate()
                self?.busy = false
            }
        }
    }
    
    func clearData() {
        dataSets.removeAll()
        historicMinX = +Double.infinity
        historicMaxX = -Double.infinity
        historicMinY = +Double.infinity
        historicMaxY = -Double.infinity
        historicMinZ = +Double.infinity
        historicMaxZ = -Double.infinity
        clearGraph()
    }
    
    private func clearGraph() {
        gridView.grid = nil
        gridView.pauseMarkers = nil
        zGridView?.grid = nil
        zGridView?.pauseMarkers = nil
        
        lastIndexXArray = nil
        
        glGraph.setPoints(points2D: [], points3D: [], min: .zero, max: .zero, timeReferenceSets: [])
    }
    
    //Mark - Toolbar and interaction
    
    func setupToolbar() -> UITabBar {
        let graphTools = UITabBar()
        
        let panZoomButton = UITabBarItem(title: localize("graph_tools_pan_and_zoom"), image: UIImage(named: "pan_zoom"), tag: Mode.pan_zoom.rawValue)
        let pickButton = UITabBarItem(title: localize("graph_tools_pick"), image: UIImage(named: "pick"), tag: Mode.pick.rawValue)
        let menuButton = UITabBarItem(title: localize("graph_tools_more"), image: UIImage(named: "more"), tag: Mode.none.rawValue)
        graphTools.items = [panZoomButton, pickButton, menuButton]
        
        graphTools.shadowImage = UIImage()
        graphTools.backgroundImage = UIImage()
        graphTools.backgroundColor = kBackgroundColor
        graphTools.tintColor = kHighlightColor
        if #available(iOS 10, *) {
            graphTools.unselectedItemTintColor = kTextColor
        }
        
        graphTools.delegate = self
        
        return graphTools
    }
    
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        switch item.tag {
        case Mode.pan_zoom.rawValue: setModePanZoom()
        case Mode.pick.rawValue: setModePick()
        case Mode.none.rawValue:
            showMenu()
            graphTools?.selectedItem = graphTools!.items![mode.rawValue]
        default:
            print("Unknown item selected.")
        }
    }
    
    func setModePanZoom() {
        mode = .pan_zoom
    }
    
    func setModePick() {
        mode = .pick
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
        let (_, _ , f) = getMenuElements()[indexPath.row]
        f()
        menuAlertController?.dismiss(animated: true, completion: nil)
    }
    
    func getMenuElements() -> [(String, Bool, () -> ())] {
        //returns [label, checked, action when clicked]
        var elements: [(String, Bool, () -> ())] = []
        
        if (descriptor.timeOnX || descriptor.timeOnY) && !hasZData {
            elements.append((localize("graph_tools_system_time"), systemTime, toggleSystemTime))
        }
        
        elements.append((localize("graph_tools_reset"), false, resetZoom))
        if (descriptor.partialUpdate) {
            elements.append((localize("graph_tools_follow"), zoomFollows, followNewData))
        }
        if (!descriptor.logX && !descriptor.logY && !hasZData) {
            elements.append((localize("graph_tools_linear_fit"), showLinearFit, linearFit))
        }
        elements.append((localize("graph_tools_export"), false, exportGraphData))
        if (descriptor.logX) {
            elements.append((localize("graph_tools_log_x"), logX, toggleLogX))
        }
        if (descriptor.logY) {
            elements.append((localize("graph_tools_log_y"), logY, toggleLogY))
        }
        
        return elements
    }
    
    var menuAlertController: UIAlertController?
    
    func showMenu() {
        
        menuAlertController = UIAlertController(title: localize("graph_tools_more"), message: nil, preferredStyle: .actionSheet)
        
        let tableView = FixedTableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.isUserInteractionEnabled = true
        
        let tableViewController = UITableViewController()
        tableViewController.tableView = tableView
        menuAlertController?.setValue(tableViewController, forKey: "contentViewController")
        
        menuAlertController?.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler: nil))
        
        if let popover = menuAlertController?.popoverPresentationController, let graphTools = graphTools {
            let interactionViews = graphTools.subviews.filter({$0.isUserInteractionEnabled})
            let view = interactionViews.sorted(by: {$0.frame.minX < $1.frame.minX})[Mode.none.rawValue]
            popover.sourceView = graphTools
            popover.sourceRect = view.frame
        }
        
        if menuAlertController != nil {
            layoutDelegate?.presentDialog(menuAlertController!)
        }
    }
    
    func resetZoom() {
        zoomMin = nil
        zoomMax = nil
        update()
    }
    
    func followNewData() {
        if !zoomFollows && (zoomMin == nil || zoomMax == nil) {
            zoomMin = GraphPoint3D(x: self.min.x, y: Double.nan, z: Double.nan)
            zoomMax = GraphPoint3D(x: self.max.x, y: Double.nan, z: Double.nan)
        }
        zoomFollows = !zoomFollows
        
        self.update()
    }
    
    func linearFit() {
        showLinearFit = !showLinearFit
        markers = []
        self.update()
    }
    
    func exportGraphData() {
        let name = self.descriptor.label
        var data: [(name: String, buffer: DataBuffer)] = []
        for i in 0..<self.descriptor.yInputBuffers.count {
            if let buffer = self.descriptor.xInputBuffers[i] {
                data.append((name: self.descriptor.localizedXLabel + (i > 0 ? " \(i+1)" : "") + (self.descriptor.localizedXUnit != "" ? "(" + self.descriptor.localizedXUnit + ")" : ""), buffer: buffer))
            }
            data.append((name: self.descriptor.localizedYLabel + (i > 0 ? " \(i+1)" : "") + (self.descriptor.localizedYUnit != "" ? "(" + self.descriptor.localizedYUnit + ")" : ""), buffer: self.descriptor.yInputBuffers[i]))
            if let buffer = self.descriptor.zInputBuffers[i] {
                data.append((name: self.descriptor.localizedZLabel + (i > 0 ? " \(i+1)" : "") + (self.descriptor.localizedZUnit != "" ? "(" + self.descriptor.localizedZUnit + ")" : ""), buffer: buffer))
            }
        }
        let export = ExperimentExport(sets: [ExperimentExportSet(name: name, data: data)])
        menuAlertController?.dismiss(animated: true, completion: {() -> Void in
            self.exportDelegate?.showExport(export, singleSet: true)
            })
    }
    
    func toggleSystemTime() {
        systemTime = !systemTime
    }
    
    func toggleLogX() {
        logX = !logX
        self.update()
    }
    
    func toggleLogY() {
        logY = !logY
        self.update()
    }
    
    //Mark - General UI
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        switch resizableState {
        case .exclusive:
            return size
        case .hidden:
            return CGSize.init(width: 0, height: 0)
        default:
            let s1 = label.sizeThatFits(size)
            let s2 = xLabel.sizeThatFits(size)
            let s3 = yLabel.sizeThatFits(size).applying(yLabel.transform)
            
            return CGSize(width: size.width, height: Swift.min((size.width-s3.width-2*sideMargins)/descriptor.aspectRatio + s1.height + s2.height + 1.0, size.height))
        }
    }
    
    private var graphFrame: CGRect {
        return gridView.insetRect.offsetBy(dx: gridView.frame.origin.x, dy: gridView.frame.origin.y)
    }
    
    private var zScaleFrame: CGRect {
        return zGridView?.insetRect.offsetBy(dx: zGridView!.frame.origin.x, dy: zGridView!.frame.origin.y) ?? .zero
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        graphArea.isHidden = resizableState == .hidden
        
        if (resizableState == .exclusive) {
            //We only need the toolbar if the graph is in fullscreen/exclusive mode, so we only set this up if the user switches to this mode.
            if (graphTools == nil) {
                graphTools = setupToolbar()
                self.addSubview(graphTools!)
            }
            if mode == .none {
                mode = .pan_zoom
            }
        } else if (graphTools != nil) {
            graphTools?.removeFromSuperview()
            graphTools = nil
            mode = .none
        }
        
        if (resizableState == .hidden) {
            return
        }
        
        let spacing: CGFloat = 1.0
        var bottom: CGFloat = 0.0
        
        if (resizableState == .exclusive) {
            if let s = graphTools?.sizeThatFits(frame.size) {
                graphTools?.frame = CGRect(x: 0, y: frame.size.height-s.height, width: frame.size.width, height: s.height)
                bottom += s.height
            }
        }
        
        graphArea.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height-bottom)
        
        let s1 = label.sizeThatFits(frame.size)
        label.frame = CGRect(x: (frame.size.width-s1.width)/2.0, y: spacing, width: s1.width, height: s1.height)
        
        let s2 = xLabel.sizeThatFits(frame.size)
        let s3 = yLabel.sizeThatFits(frame.size).applying(yLabel.transform)
        
        xLabel.frame = CGRect(x: (frame.size.width+s3.width-s2.width)/2.0, y: frame.size.height-s2.height-spacing-bottom, width: s2.width, height: s2.height)
        
        bottom += s2.height+spacing
        
        let s4 = zLabel?.sizeThatFits(frame.size) ?? .zero
        zLabel?.frame = CGRect(x: (frame.size.width+s3.width-s4.width)/2.0, y: s1.height + spacing + zScaleHeight, width: s4.width, height: s4.height)
        
        gridView.frame = CGRect(x: sideMargins + s3.width + spacing, y: s1.height+spacing+(hasZData ? zScaleHeight + s4.height + spacing : 0), width: frame.size.width - s3.width - spacing - 2*sideMargins, height: frame.size.height - s1.height - spacing - bottom - (hasZData ? zScaleHeight + spacing + s4.height : 0))
        zGridView?.frame = CGRect(x: sideMargins + s3.width + spacing, y: s1.height+spacing, width: frame.size.width - s3.width - spacing - 2*sideMargins, height: zScaleHeight)
        
        yLabel.frame = CGRect(x: sideMargins, y: graphFrame.origin.y+(graphFrame.size.height-s3.height)/2.0, width: s3.width, height: s3.height - bottom)
        
        updatePlotArea()
    }
    
}

extension ExperimentGraphView: GraphGridDelegate {
    func updatePlotArea() {
        if (glGraph.frame != graphFrame) {
            glGraph.frame = graphFrame
            glGraph.setNeedsLayout()
            glZScale?.frame = zScaleFrame
            glZScale?.setNeedsLayout()
            markerOverlayView.frame = graphFrame
            refreshMarkers()
        }
    }
}

extension ExperimentGraphView: DisplayLinkListener {
    func display(_ displayLink: DisplayLink) {
        if wantsUpdate {
            update()
        }
    }
}
