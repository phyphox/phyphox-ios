//
//  ExperimentGraphView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit

final class ExperimentGraphView: UIView, DynamicViewModule, ResizableViewModule, DescriptorBoundViewModule, GraphViewModule, UITabBarDelegate {
    
    private let sideMargins:CGFloat = 10.0
    
    let descriptor: GraphViewDescriptor
    
    var layoutDelegate: ModuleExclusiveLayoutDelegate? = nil
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
    
    private let glGraph: GLGraphView
    private let gridView: GraphGridView
    
    private var zoomMin: GraphPoint<Double>?
    private var zoomMax: GraphPoint<Double>?
    private var zoomFollows = false

    var panGestureRecognizer: UIPanGestureRecognizer? = nil
    var pinchGestureRecognizer: UIPinchGestureRecognizer? = nil
    
    private let queue = DispatchQueue(label: "de.rwth-aachen.phyphox.graphview", qos: .userInitiated, attributes: [], autoreleaseFrequency: .inherit, target: nil)

    private var dataSets: [(bounds: (min: GraphPoint<Double>, max: GraphPoint<Double>), data: [GraphPoint<GLfloat>])] = []
    
    private func addDataSet(_ set: (bounds: (min: GraphPoint<Double>, max: GraphPoint<Double>), data: [GraphPoint<GLfloat>])) {
        if dataSets.count >= Int(descriptor.history) {
            dataSets.removeFirst()
        }
        
        dataSets.append(set)
    }
    
    private var max: GraphPoint<Double> {
        if dataSets.count > 1 {
            var maxX = -Double.infinity
            var maxY = -Double.infinity
            
            for set in dataSets {
                let maxPoint = set.bounds.max

                maxX = Swift.max(maxX, maxPoint.x)
                maxY = Swift.max(maxY, maxPoint.y)
            }
            
            return GraphPoint(x: maxX, y: maxY)
        }
        else {
            return dataSets.first?.bounds.max ?? .zero
        }
    }
    
    private var min: GraphPoint<Double> {
        if dataSets.count > 1 {
            var minX = Double.infinity
            var minY = Double.infinity
            
            for set in dataSets {
                let minPoint = set.bounds.min
                
                minX = Swift.min(minX, minPoint.x)
                minY = Swift.min(minY, minPoint.y)
            }
            
            return GraphPoint(x: minX, y: minY)
        }
        else {
            return dataSets.first?.bounds.min ?? .zero
        }
    }
    
    private var points: [[GraphPoint<GLfloat>]] {
        return dataSets.map { $0.data }
    }
    
    required init?(descriptor: GraphViewDescriptor) {
        self.descriptor = descriptor
        
        glGraph = GLGraphView()
        glGraph.drawDots = descriptor.drawDots
        glGraph.lineWidth = Float(descriptor.lineWidth * (descriptor.drawDots ? 4.0 : 2.0))
        var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
        
        descriptor.color.getRed(&r, green: &g, blue: &b, alpha: &a)
        glGraph.lineColor = GLcolor(r: Float(r), g: Float(g), b: Float(b), a: Float(a))
        glGraph.historyLength = descriptor.history
        
        gridView = GraphGridView(descriptor: descriptor)
        gridView.gridInset = CGPoint(x: 2.0, y: 2.0)
        gridView.gridOffset = CGPoint(x: 0.0, y: 0.0)
        
        func makeLabel(_ text: String?) -> UILabel {
            let l = UILabel()
            l.text = text
            
            let defaultFont = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
            l.font = defaultFont.withSize(defaultFont.pointSize * 0.8)
            
            return l
        }
        
        label.numberOfLines = 0
        label.text = descriptor.localizedLabel
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = kTextColor
        
        xLabel = makeLabel(descriptor.localizedXLabel)
        yLabel = makeLabel(descriptor.localizedYLabel)
        xLabel.textColor = kTextColor
        yLabel.textColor = kTextColor
        yLabel.transform = CGAffineTransform(rotationAngle: -CGFloat(Double.pi/2.0))
        
        super.init(frame: .zero)
        
        gridView.delegate = self

        graphArea.addSubview(label)
        graphArea.addSubview(gridView)
        graphArea.addSubview(glGraph)
        graphArea.addSubview(xLabel)
        graphArea.addSubview(yLabel)
        
        addSubview(graphArea)

        registerForUpdatesFromBuffer(descriptor.yInputBuffer)
        if let xBuffer = descriptor.xInputBuffer {
            registerForUpdatesFromBuffer(xBuffer)
        }

        attachDisplayLink(displayLink)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ExperimentGraphView.tapped(_:)))
        graphArea.addGestureRecognizer(tapGesture)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func resizableStateChanged(_ newState: ResizableViewModuleState) {
        if newState == .exclusive {
            panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(ExperimentGraphView.panned(_:)))
            pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(ExperimentGraphView.pinched(_:)))
            if let gr = panGestureRecognizer {
                glGraph.addGestureRecognizer(gr)
            }
            if let gr = pinchGestureRecognizer {
                glGraph.addGestureRecognizer(gr)
            }
        } else {
            if let gr = panGestureRecognizer {
                glGraph.removeGestureRecognizer(gr)
            }
            if let gr = pinchGestureRecognizer {
                glGraph.removeGestureRecognizer(gr)
            }
            panGestureRecognizer = nil
            pinchGestureRecognizer = nil
        }
    }
    
    @objc func tapped(_ sender: UITapGestureRecognizer) {
        if resizableState == .normal {
            layoutDelegate?.presentExclusiveLayout(self)
        } else {
            layoutDelegate?.restoreLayout()
        }
    }
    
    var panStartMin: GraphPoint<Double>?
    var panStartMax: GraphPoint<Double>?
    
    @objc func panned (_ sender: UIPanGestureRecognizer) {
        if (mode != .pan_zoom) {
            return
        }
        
        zoomFollows = false
        
        let offset = sender.translation(in: self)
        
        let min = self.min
        let max = self.max
        
        if sender.state == .began {
            panStartMin = min
            panStartMax = max
        }
        
        guard let startMin = panStartMin, let startMax = panStartMax else {
            return
        }
        
        let dx = Double(offset.x / self.frame.width) * (max.x - min.x)
        let dy = Double(offset.y / self.frame.height) * (min.y - max.y)
        
        zoomMin = GraphPoint(x: startMin.x - dx, y: startMin.y - dy)
        zoomMax = GraphPoint(x: startMax.x - dx, y: startMax.y - dy)
        
        self.update()
    }
    
    var pinchOrigin: GraphPoint<Double>?
    var pinchScale: GraphPoint<Double>?
    var pinchTouchScale: GraphPoint<CGFloat>?
    
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
            pinchTouchScale = GraphPoint(x: abs(t1.x - t2.x)/sender.scale, y: abs(t1.y - t2.y)/sender.scale)
            pinchScale = GraphPoint(x: max.x - min.x, y: max.y - min.y)
            pinchOrigin = GraphPoint(x: min.x + Double(centerX)/Double(self.frame.width)*pinchScale!.x, y: max.y - Double(centerY)/Double(self.frame.height)*pinchScale!.y)
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
        
        let zoomMinX = origin.x - Double(centerX)/Double(self.frame.width) * scaleX
        let zoomMaxX = zoomMinX + scaleX
        let zoomMaxY = origin.y + Double(centerY)/Double(self.frame.height) * scaleY
        let zoomMinY = zoomMaxY - scaleY
        zoomMin = GraphPoint(x: zoomMinX, y: zoomMinY)
        zoomMax = GraphPoint(x: zoomMaxX, y: zoomMaxY)
        
        self.update()
    }
    
    //MARK - Graph
    
    private var lastIndexXArray: [Double]?
    private var lastCount: Int?

    private func runUpdate() {
        var xValues: [Double]

        let yValues = descriptor.yInputBuffer.toArray()
        let yCount = yValues.count

        var count = yCount

        if count <= 1 {
            mainThread {
                self.clearGraph()
            }
            return
        }

        if let xBuf = descriptor.xInputBuffer {
            xValues = xBuf.toArray()
            let xCount = xValues.count

            count = Swift.min(xCount, count)
        }
        else {
            var xC = 0

            if lastIndexXArray != nil {
                xC = lastIndexXArray!.count
            }

            let delta = count-xC

            if delta > 0 && lastIndexXArray == nil {
                lastIndexXArray = []
            }

            for i in xC..<count {
                lastIndexXArray!.append(Double(i))
            }

            if lastIndexXArray == nil {
                mainThread {
                    self.clearGraph()
                }
                return
            }

            xValues = lastIndexXArray!
        }

        count = Swift.min(xValues.count, yValues.count)

        if count <= 1 {
            mainThread {
                self.clearGraph()
            }
            return
        }

        var points: [GraphPoint<GLfloat>] = []
        points.reserveCapacity(count)

        var lastX = -Double.infinity

        let logX = descriptor.logX
        let logY = descriptor.logY

        var minX = Double.infinity
        var maxX = -Double.infinity

        var minY = Double.infinity
        var maxY = -Double.infinity

        var xMinStrict = descriptor.scaleMinX == .fixed
        var xMaxStrict = descriptor.scaleMaxX == .fixed
        var yMinStrict = descriptor.scaleMinY == .fixed
        var yMaxStrict = descriptor.scaleMaxY == .fixed

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
        
        if let zMin = zoomMin, let zMax = zoomMax {
            minX = zMin.x
            maxX = zMax.x
            xMinStrict = true
            xMaxStrict = true
            if (zMin.y.isFinite && zMax.y.isFinite) {
                minY = zMin.y
                maxY = zMax.y
                yMinStrict = true
                yMaxStrict = true
            }
        }

        var xOrderOK = true
        var valuesOK = true

        for i in 0..<count {
            let rawX = xValues[i]
            let rawY = yValues[i]

            if rawX < lastX {
                xOrderOK = false
            }

            lastX = rawX

            let x = (logX ? log(rawX) : rawX)
            let y = (logY ? log(rawY) : rawY)

            guard x.isFinite && y.isFinite else {
                valuesOK = false
                continue
            }

            if x < minX && !xMinStrict {
                minX = x
            }

            if x > maxX {
                if !xMaxStrict {
                    maxX = x
                } else if zoomFollows && zoomMin != nil && zoomMax != nil {
                    let w = zoomMax!.x - zoomMin!.x
                    zoomMin = GraphPoint(x: x - w, y: zoomMin!.y)
                    zoomMax = GraphPoint(x: x, y: zoomMax!.y)
                    minX = zoomMin!.x
                    maxX = zoomMax!.x
                }
            }

            if y < minY && !yMinStrict {
                minY = y
            }

            if y > maxY && !yMaxStrict {
                maxY = y
            }

            points.append(GraphPoint(x: GLfloat(x), y: GLfloat(y)))
        }

        if !xOrderOK {
            print("x values are not ordered!")
        }

        if !valuesOK {
            print("Tried drawing NaN or inf")
        }

        let dataSet = (bounds: (min: GraphPoint(x: minX, y: minY), max: GraphPoint(x: maxX, y: maxY)), data: points)

        addDataSet(dataSet)

        let grid = generateGrid(logX: logX, logY: logY)

        let finalPoints = self.points

        let min = self.min
        let max = self.max

        mainThread {
            self.gridView.grid = grid
            self.glGraph.setPoints(finalPoints, min: min, max: max)
        }
    }

    private func generateGrid(logX: Bool, logY: Bool) -> GraphGrid {
        let min = self.min
        let max = self.max

        let minX = min.x
        let maxX = max.x

        let minY = min.y
        let maxY = max.y

        let xRange = maxX - minX
        let yRange = maxY - minY

        let xTicks = ExperimentGraphUtilities.getTicks(minX, max: maxX, maxTicks: 6, log: logX)
        let yTicks = ExperimentGraphUtilities.getTicks(minY, max: maxY, maxTicks: 6, log: logY)

        let mappedXTicks = xTicks.map({ (val) -> GraphGridLine in
            return GraphGridLine(absoluteValue: val, relativeValue: CGFloat(((logX ? log(val) : val) - minX) / xRange))
        })

        let mappedYTicks = yTicks.map({ (val) -> GraphGridLine in
            return GraphGridLine(absoluteValue: val, relativeValue: CGFloat(((logY ? log(val) : val) - minY) / yRange))
        })

        return GraphGrid(xGridLines: mappedXTicks, yGridLines: mappedYTicks)
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
        clearGraph()
    }
    
    private func clearGraph() {
        gridView.grid = nil
        
        lastIndexXArray = nil
        
        glGraph.setPoints([], min: .zero, max: .zero)
    }
    
    //Mark - Toolbar and interaction
    
    func setupToolbar() -> UITabBar {
        let graphTools = UITabBar()
        
        let panZoomButton = UITabBarItem(title: NSLocalizedString("graph_tools_pan_and_zoom", comment: ""), image: UIImage(named: "pan_zoom"), tag: Mode.pan_zoom.rawValue)
        let pickButton = UITabBarItem(title: NSLocalizedString("graph_tools_pick", comment: ""), image: UIImage(named: "pick"), tag: Mode.pick.rawValue)
        let menuButton = UITabBarItem(title: NSLocalizedString("graph_tools_more", comment: ""), image: UIImage(named: "more"), tag: Mode.none.rawValue)
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
    
    func showMenu() {
        let alert = UIAlertController(title: NSLocalizedString("graph_tools_more", comment: ""), message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("graph_tools_reset", comment: ""), style: .default, handler: resetZoom))
        alert.addAction(UIAlertAction(title: NSLocalizedString("graph_tools_follow", comment: "") + (zoomFollows ? " \u{2714}" : ""), style: .default, handler: followNewData))
        alert.addAction(UIAlertAction(title: NSLocalizedString("graph_tools_linear_fit", comment: "") + " \u{2714}", style: .default, handler: linearFit))
        alert.addAction(UIAlertAction(title: NSLocalizedString("graph_tools_export", comment: ""), style: .default, handler: exportGraphData))
        alert.addAction(UIAlertAction(title: NSLocalizedString("graph_tools_log_x", comment: "") + " \u{2714}", style: .default, handler: toggleLogX))
        alert.addAction(UIAlertAction(title: NSLocalizedString("graph_tools_log_y", comment: "") + " \u{2714}", style: .default, handler: toggleLogY))
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            let interactionViews = graphTools!.subviews.filter({$0.isUserInteractionEnabled})
            let view = interactionViews.sorted(by: {$0.frame.minX < $1.frame.minX})[Mode.none.rawValue]
            popover.sourceView = view
            popover.sourceRect = view.frame
        }
        
        layoutDelegate?.presentDialog(alert)
    }
    
    func resetZoom(_ action: UIAlertAction) {
        print("Reset zoom")
    }
    
    func followNewData(_ action: UIAlertAction) {
        if !zoomFollows && (zoomMin == nil || zoomMax == nil) {
            zoomMin = GraphPoint(x: self.min.x, y: Double.nan)
            zoomMax = GraphPoint(x: self.max.x, y: Double.nan)
        }
        zoomFollows = !zoomFollows
        
        self.update()
    }
    
    func linearFit(_ action: UIAlertAction) {
        print("Linear fit")
    }
    
    func exportGraphData(_ action: UIAlertAction) {
        print("Export graph data")
    }
    
    func toggleLogX(_ action: UIAlertAction) {
        print("Toggle log x")
    }
    
    func toggleLogY(_ action: UIAlertAction) {
        print("Toogle log y")
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
            if let s = graphTools?.sizeThatFits(bounds.size) {
                graphTools?.frame = CGRect(x: 0, y: bounds.size.height-s.height, width: bounds.size.width, height: s.height)
                bottom += s.height
            }
        }
        
        graphArea.frame = CGRect(x: 0, y: 0, width: bounds.size.width, height: bounds.size.height-bottom)
        
        let s1 = label.sizeThatFits(bounds.size)
        label.frame = CGRect(x: (bounds.size.width-s1.width)/2.0, y: spacing, width: s1.width, height: s1.height)
        
        let s2 = xLabel.sizeThatFits(bounds.size)
        xLabel.frame = CGRect(x: (bounds.size.width-s2.width)/2.0, y: bounds.size.height-s2.height-spacing-bottom, width: s2.width, height: s2.height)
        
        let s3 = yLabel.sizeThatFits(bounds.size).applying(yLabel.transform)
        
        bottom += s2.height+spacing
        
        gridView.frame = CGRect(x: sideMargins + s3.width + spacing, y: s1.height+spacing, width: bounds.size.width - s3.width - spacing - 2*sideMargins, height: bounds.size.height - s1.height - spacing - bottom)
        
        yLabel.frame = CGRect(x: sideMargins, y: graphFrame.origin.y+(graphFrame.size.height-s3.height)/2.0, width: s3.width, height: s3.height - bottom)
        
        updatePlotArea()
    }
    
    func animateFrame(_ frame: CGRect) {
        layoutIfNeeded()
        UIView.animate(withDuration: 0.15, animations: {
            self.frame = frame
            self.layoutIfNeeded()
        })
    }
    
}

extension ExperimentGraphView: GraphGridDelegate {
    func updatePlotArea() {
        if (glGraph.frame != graphFrame) {
            glGraph.frame = graphFrame
            glGraph.setNeedsLayout()
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
