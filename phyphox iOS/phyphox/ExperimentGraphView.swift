//
//  ExperimentGraphView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

struct GraphGrid {
    let xGridLines: [GraphGridLine]?
    let yGridLines: [GraphGridLine]?
}

struct GraphGridLine {
    let absoluteValue: Double
    let relativeValue: CGFloat
}

final class ExperimentGraphView: ExperimentViewModule<GraphViewDescriptor>, DataBufferObserver, GraphGridDelegate {
    var isExclusiveView = false
    typealias T = GraphViewDescriptor
    
    private let xLabel: UILabel
    private let yLabel: UILabel
    
    private let glGraph: GLGraphView
    private let gridView: GraphGridView
    
    private var maxX: Double
    private var minX: Double
    private var maxY: Double
    private var minY: Double
    
    private var zoomMaxX: Double
    private var zoomMinX: Double
    private var zoomMaxY: Double
    private var zoomMinY: Double
    
    var panGesture: UIPanGestureRecognizer? = nil
    var pinchGesture: UIPinchGestureRecognizer? = nil
    
    var queue: dispatch_queue_t!
    
    private var dataSets: [(bounds: (min: GraphPoint<Double>, max: GraphPoint<Double>), data: [GraphPoint<GLfloat>])] = []
    
    func addDataSet(set: (bounds: (min: GraphPoint<Double>, max: GraphPoint<Double>), data: [GraphPoint<GLfloat>])) {
        if self.dataSets.count >= Int(self.descriptor.history) {
            self.dataSets.removeFirst()
        }
        
        self.dataSets.append(set)
    }
    
    private var max: GraphPoint<Double>? {
        if dataSets.count > 1 {
            var maxX = -Double.infinity
            var maxY = -Double.infinity
            
            for set in dataSets {
                let maxPoint = set.bounds.max
                
                if maxPoint.x > maxX {
                    maxX = maxPoint.x
                }
                
                if maxPoint.y > maxY {
                    maxY = maxPoint.y
                }
            }
            
            return GraphPoint(x: maxX, y: maxY)
        }
        else {
            return dataSets.first?.bounds.max
        }
    }
    
    private var min: GraphPoint<Double>? {
        if dataSets.count > 1 {
            var minX = Double.infinity
            var minY = Double.infinity
            
            for set in dataSets {
                let minPoint = set.bounds.min
                
                if minPoint.x < minX {
                    minX = minPoint.x
                }
                
                if minPoint.y < minY {
                    minY = minPoint.y
                }
            }
            
            return GraphPoint(x: minX, y: minY)
        }
        else {
            return dataSets.first?.bounds.min
        }
    }
    
    private var points: [[GraphPoint<GLfloat>]] {
        return dataSets.map{$0.data}
    }
    
    required init(descriptor: GraphViewDescriptor) {
        self.maxX = -Double.infinity
        self.minX = Double.infinity
        
        self.maxY = -Double.infinity
        self.minY = Double.infinity
        
        self.zoomMinX = Double.NaN
        self.zoomMaxX = Double.NaN
        self.zoomMinY = Double.NaN
        self.zoomMaxY = Double.NaN
        
        glGraph = GLGraphView()
        glGraph.drawDots = descriptor.drawDots
        glGraph.lineWidth = Float(descriptor.lineWidth * (descriptor.drawDots ? 4.0 : 2.0))
        var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
        
        descriptor.color.getRed(&r, green: &g, blue: &b, alpha: &a)
        glGraph.lineColor = GLcolor(r: Float(r), g: Float(g), b: Float(b), a: Float(a))
        glGraph.historyLength = descriptor.history
        
        gridView = GraphGridView(descriptor: descriptor)
        gridView.gridInset = CGPointMake(2.0, 2.0)
        gridView.gridOffset = CGPointMake(0.0, 0.0)
        
        func makeLabel(text: String?) -> UILabel {
            let l = UILabel()
            l.text = text
            
            let defaultFont = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
            l.font = defaultFont.fontWithSize(defaultFont.pointSize * 0.8)
            
            return l
        }
        
        xLabel = makeLabel(descriptor.localizedXLabel)
        yLabel = makeLabel(descriptor.localizedYLabel)
        xLabel.textColor = kTextColor
        yLabel.textColor = kTextColor
        yLabel.transform = CGAffineTransformMakeRotation(-CGFloat(M_PI/2.0))
        
        super.init(descriptor: descriptor)
        
        gridView.delegate = self
        
        addSubview(gridView)
        addSubview(glGraph)
        addSubview(xLabel)
        addSubview(yLabel)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ExperimentGraphView.tapped(_:)))
        glGraph.addGestureRecognizer(tapGesture)
        
        descriptor.yInputBuffer.addObserver(self)
    }
    
    func tapped(sender: UITapGestureRecognizer) {
        if isExclusiveView {
            isExclusiveView = false
            glGraph.removeGestureRecognizer(panGesture!)
            glGraph.removeGestureRecognizer(pinchGesture!)
            panGesture = nil
            pinchGesture = nil
            self.delegate?.hideExclusiveView()
        } else {
            isExclusiveView = true
            self.delegate?.presentExclusiveView(self)
            panGesture = UIPanGestureRecognizer(target: self, action: #selector(ExperimentGraphView.panned(_:)))
            pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(ExperimentGraphView.pinched(_:)))
            glGraph.addGestureRecognizer(panGesture!)
            glGraph.addGestureRecognizer(pinchGesture!)
        }
    }
    
    var panStartMinX = Double.NaN
    var panStartMaxX = Double.NaN
    var panStartMinY = Double.NaN
    var panStartMaxY = Double.NaN
    
    func panned(sender: UIPanGestureRecognizer) {
        let offset = sender.translationInView(self)
        
        if sender.state == .Began {
            panStartMinX = self.minX
            panStartMaxX = self.maxX
            panStartMinY = self.minY
            panStartMaxY = self.maxY
        }
        
        let dx = Double(offset.x / self.frame.width) * (self.maxX - self.minX)
        let dy = Double(offset.y / self.frame.height) * (self.minY - self.maxY)
        
        zoomMinX = panStartMinX - dx
        zoomMaxX = panStartMaxX - dx
        zoomMinY = panStartMinY - dy
        zoomMaxY = panStartMaxY - dy
        
        self.update()
    }
    
    
    var pinchCoordOriginX = Double.NaN
    var pinchCoordOriginY = Double.NaN
    var pinchCoordScaleX = Double.NaN
    var pinchCoordScaleY = Double.NaN
    var pinchTouchScaleX = CGFloat.NaN
    var pinchTouchScaleY = CGFloat.NaN
    
    func pinched(sender: UIPinchGestureRecognizer) {
        if sender.numberOfTouches() != 2 {
            return
        }
        
        let maxX = self.maxX
        let minX = self.minX
        let maxY = self.maxY
        let minY = self.minY
        
        let t1 = sender.locationOfTouch(0, inView: self)
        let t2 = sender.locationOfTouch(1, inView: self)
        
        let centerX = (t1.x + t2.x)/2.0;
        let centerY = (t1.y + t2.y)/2.0;
        
        if sender.state == .Began {
            pinchTouchScaleX = abs(t1.x - t2.x)/sender.scale;
            pinchTouchScaleY = abs(t1.y - t2.y)/sender.scale;
            
            pinchCoordScaleX = maxX-minX
            pinchCoordScaleY = maxY-minY
            pinchCoordOriginX = minX + Double(centerX)/Double(self.frame.width)*(pinchCoordScaleX)
            pinchCoordOriginY = maxY - Double(centerY)/Double(self.frame.height)*(pinchCoordScaleY)
        }
        
        let dx = abs(t1.x-t2.x)
        let dy = abs(t1.y-t2.y)
        
        var scaleX: Double
        var scaleY: Double
        
        if pinchTouchScaleX/pinchTouchScaleY > 0.5 {
            scaleX = Double(pinchTouchScaleX / dx) * pinchCoordScaleX
        } else {
            scaleX = pinchCoordScaleX
        }
        if pinchTouchScaleY/pinchTouchScaleX > 0.5 {
            scaleY = Double(pinchTouchScaleY / dy) * pinchCoordScaleY
        } else {
            scaleY = pinchCoordScaleY
        }
        
        if scaleX > 10*pinchCoordScaleX {
            scaleX = 10*pinchCoordScaleX
        }
        
        if scaleY > 10*pinchCoordScaleY {
            scaleY = 10*pinchCoordScaleY
        }
        
        zoomMinX = pinchCoordOriginX - Double(centerX)/Double(self.frame.width) * scaleX
        zoomMaxX = zoomMinX + scaleX
        zoomMaxY = pinchCoordOriginY + Double(centerY)/Double(self.frame.height) * scaleY
        zoomMinY = zoomMaxY - scaleY
        
        self.update()
    }
    
    override func unregisterFromBuffer() {
        descriptor.yInputBuffer.removeObserver(self)
    }
    
    func dataBufferUpdated(buffer: DataBuffer, noData: Bool) {
        setNeedsUpdate()
    }
    
    //MARK - Graph
    func getTicks(min: Double, max: Double, maxTicks: Int, log: Bool) -> [Double]? {
        if max <= min || !isfinite(min) || !isfinite(max) {
            return nil
        }
        
        var tickLocations = [Double]()
        tickLocations.reserveCapacity(maxTicks)
        
        if log {
            let expMax = exp(max)
            let expMin = exp(min)
            let logMax = log10(expMax)
            let logMin = log10(expMin)
            
            let digitRange = Int(ceil(logMax)-floor(logMin))
            if (digitRange < 1) {
                return nil
            }
            
            var first: Double = pow(10, floor(logMin))
            
            var magStep = 1
            while digitRange > maxTicks * magStep {
                magStep += 1
            }
            let magFactor: Double = pow(10.0, Double(magStep))
            
            for _ in 0..<digitRange {
                if first > expMax || tickLocations.count >= maxTicks {
                    break
                }
                if (first > expMin) {
                    tickLocations.append(Double(first))
                }
                
                if (digitRange < 4) {
                    if 2*first > expMax || tickLocations.count >= maxTicks {
                        break
                    }
                    if (2*first > expMin) {
                        tickLocations.append(Double(2*first))
                    }
                }
                
                if (digitRange < 3) {
                    if 5*first > expMax || tickLocations.count >= maxTicks {
                        break
                    }
                    if (5*first > expMin) {
                        tickLocations.append(Double(5*first))
                    }
                }
                
                first *= magFactor
            }
            return tickLocations
        }
        
        let range = max-min
        
        let stepFactor = pow(10.0, floor(log10(range))-1)
        var step = 1.0
        let steps = Int(range/stepFactor)
        
        if (steps <= maxTicks) {
            step = 1*stepFactor
        }
        else if (steps <= maxTicks * 2) {
            step = 2*stepFactor
        }
        else if (steps <= maxTicks * 5) {
            step = 5*stepFactor
        }
        else if (steps <= maxTicks * 10) {
            step = 10*stepFactor
        }
        else if (steps <= maxTicks * 20) {
            step = 20*stepFactor
        }
        else if (steps <= maxTicks * 50) {
            step = 50*stepFactor
        }
        else if (steps <= maxTicks * 100) {
            step = 100*stepFactor
        }
        else if (steps <= maxTicks * 250) {
            step = 250*stepFactor
        }
        else if (steps <= maxTicks * 500) {
            step = 500*stepFactor
        }
        else if (steps <= maxTicks * 1000) {
            step = 1000*stepFactor
        }
        else if (steps <= maxTicks * 2000) {
            step = 2000*stepFactor
        }
        
        let first = ceil(min/step)*step
        
        var i = 0
        
        while true {
            let s = first+Double(i)*step
            
            if s > max || tickLocations.count >= maxTicks {
                break
            }
            
            tickLocations.append(s)
            i += 1
        }
        
        return tickLocations
    }
    
    private var lastIndexXArray: [Double]?
    private var lastCount: Int?
    
    private var lastCut: Int = 0
    
    private var hasUpdateBlockEnqueued = false
    
    override func update() {
        if hasUpdateBlockEnqueued || superview == nil || window == nil {
            return
        }
        
        hasUpdateBlockEnqueued = true
        
        dispatch_async(queue) { [unowned self] in
            autoreleasepool({
                var xValues: [Double]
                
                let yValues = self.descriptor.yInputBuffer.toArray()
                let yCount = Swift.min(yValues.count, self.descriptor.yInputBuffer.actualCount)
                
                var trashedCount = self.descriptor.yInputBuffer.trashedCount
                
                var count = yCount
                
                if count <= 1 {
                    mainThread {
                        self.clearGraph()
                    }
                    return
                }
                
                if let xBuf = self.descriptor.xInputBuffer {
                    xValues = xBuf.toArray()
                    let xCount = Swift.min(xValues.count, xBuf.actualCount)
                    
                    count = Swift.min(xCount, count)
                    
                    trashedCount = Swift.min(xBuf.trashedCount, trashedCount)
                }
                else {
                    var xC = 0
                    
                    if self.lastIndexXArray != nil {
                        xC = self.lastIndexXArray!.count
                    }
                    
                    let delta = count-xC
                    
                    if delta > 0 && self.lastIndexXArray == nil {
                        self.lastIndexXArray = []
                    }
                    
                    for i in xC..<count {
                        self.lastIndexXArray!.append(Double(i))
                    }
                    
                    if self.lastIndexXArray == nil {
                        mainThread {
                            self.clearGraph()
                        }
                        return
                    }
                    
                    xValues = self.lastIndexXArray!
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
                
                let logX = self.descriptor.logX
                let logY = self.descriptor.logY
                
                if self.zoomMinX.isFinite {
                    self.minX = self.zoomMinX
                } else {
                    switch self.descriptor.scaleMinX {
                        case GraphViewDescriptor.scaleMode.auto:
                            self.minX = Double.infinity
                        case GraphViewDescriptor.scaleMode.extend:
                            break
                        case GraphViewDescriptor.scaleMode.fixed:
                            self.minX = Double(self.descriptor.minX)
                    }
                }
                
                if self.zoomMaxX.isFinite {
                    self.maxX = self.zoomMaxX
                } else {
                    switch self.descriptor.scaleMaxX {
                        case GraphViewDescriptor.scaleMode.auto:
                            self.maxX = -Double.infinity
                        case GraphViewDescriptor.scaleMode.extend:
                            break
                        case GraphViewDescriptor.scaleMode.fixed:
                            self.maxX = Double(self.descriptor.maxX)
                    }
                }
                
                if self.zoomMinY.isFinite {
                    self.minY = self.zoomMinY
                } else {
                    switch self.descriptor.scaleMinY {
                        case GraphViewDescriptor.scaleMode.auto:
                            self.minY = Double.infinity
                        case GraphViewDescriptor.scaleMode.extend:
                            break
                        case GraphViewDescriptor.scaleMode.fixed:
                            self.minY = Double(self.descriptor.minY)
                    }
                }
                
                if self.zoomMaxY.isFinite {
                    self.maxY = self.zoomMaxY
                } else {
                    switch self.descriptor.scaleMaxY {
                        case GraphViewDescriptor.scaleMode.auto:
                            self.maxY = -Double.infinity
                        case GraphViewDescriptor.scaleMode.extend:
                            break
                        case GraphViewDescriptor.scaleMode.fixed:
                            self.maxY = Double(self.descriptor.maxY)
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
                    
                    guard isfinite(x) && isfinite(y) else {
                        valuesOK = false
                        continue
                    }
                    
                    if x < self.minX && self.descriptor.scaleMinX != GraphViewDescriptor.scaleMode.fixed && !self.zoomMinX.isFinite {
                        self.minX = x
                    }
                    
                    if x > self.maxX && self.descriptor.scaleMaxX != GraphViewDescriptor.scaleMode.fixed && !self.zoomMaxX.isFinite {
                        self.maxX = x
                    }
                    
                    if y < self.minY && self.descriptor.scaleMinY != GraphViewDescriptor.scaleMode.fixed && !self.zoomMinY.isFinite {
                        self.minY = y
                    }
                    
                    if y > self.maxY && self.descriptor.scaleMaxY != GraphViewDescriptor.scaleMode.fixed && !self.zoomMaxY.isFinite {
                        self.maxY = y
                    }
                    
                    points.append(GraphPoint(x: GLfloat(x), y: GLfloat(y)))
                }
                
                if !xOrderOK {
                    print("x values are not ordered!")
                }
                
                if !valuesOK {
                    print("Tried drawing NaN or inf")
                }
                
                let dataSet = (bounds: (min: GraphPoint(x: self.minX, y: self.minY), max: GraphPoint(x: self.maxX, y: self.maxY)), data: points)
                
                self.addDataSet(dataSet)
                
                let min = self.min!
                let max = self.max!
                
                self.minX = min.x
                self.maxX = max.x
                
                self.minY = min.y
                self.maxY = max.y
                
                let xTicks = self.getTicks(self.minX, max: self.maxX, maxTicks: 6, log: logX)
                let yTicks = self.getTicks(self.minY, max: self.maxY, maxTicks: 6, log: logY)
                
                var mappedXTicks: [GraphGridLine]? = nil
                var mappedYTicks: [GraphGridLine]? = nil
                
                if xTicks != nil {
                    mappedXTicks = xTicks!.map({ (val) -> GraphGridLine in
                        return GraphGridLine(absoluteValue: val, relativeValue: CGFloat(((logX ? log(val) : val)-self.minX)/(self.maxX-self.minX)))
                    })
                }
                
                if yTicks != nil {
                    mappedYTicks = yTicks!.map({ (val) -> GraphGridLine in
                        return GraphGridLine(absoluteValue: val, relativeValue: CGFloat(((logY ? log(val) : val)-self.minY)/(self.maxY-self.minY)))
                    })
                }
                
                let finalPoints = self.points
                
                mainThread {
                    self.gridView.grid = GraphGrid(xGridLines: mappedXTicks, yGridLines: mappedYTicks)
                    self.glGraph.setPoints(finalPoints, min: min, max: max)
                }
            })
            
            self.hasUpdateBlockEnqueued = false
        }
    }
    
    func clearAllDataSets() {
        dataSets.removeAll()
        clearGraph()
    }
    
    func clearGraph() {
        self.maxX = -Double.infinity
        self.minX = Double.infinity
        
        self.maxY = -Double.infinity
        self.minY = Double.infinity
        
        self.gridView.grid = nil
        
        self.lastIndexXArray = nil
        
        self.glGraph.setPoints([], min: nil, max: nil)
    }
    
    //Mark - General UI
    
    override func sizeThatFits(size: CGSize) -> CGSize {
        let s1 = label.sizeThatFits(self.bounds.size)
        
        //For now, we just zoom, but eventually we want to add some controls and maybe not zoom in all the way right away?
        if isExclusiveView {
            return CGSizeMake(size.width, size.height)
        } else {
            return CGSizeMake(size.width, Swift.min(size.width/descriptor.aspectRatio + s1.height + 1.0, size.height))
        }
    }
    
    var graphFrame: CGRect {
        return CGRectOffset(gridView.insetRect, gridView.frame.origin.x, gridView.frame.origin.y)
    }
    
    func updatePlotArea() {
        if (self.glGraph.frame != self.graphFrame) {
            self.glGraph.frame = self.graphFrame
            self.glGraph.setNeedsLayout()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let spacing: CGFloat = 1.0
        
        let s1 = label.sizeThatFits(self.bounds.size)
        label.frame = CGRectMake((self.bounds.size.width-s1.width)/2.0, spacing, s1.width, s1.height)
        
        let s2 = xLabel.sizeThatFits(self.bounds.size)
        xLabel.frame = CGRectMake((self.bounds.size.width-s2.width)/2.0, self.bounds.size.height-s2.height-spacing, s2.width, s2.height)
        
        let s3 = CGSizeApplyAffineTransform(yLabel.sizeThatFits(self.bounds.size), yLabel.transform)
        
        gridView.frame = CGRectMake(s3.width + spacing, s1.height+spacing, self.bounds.size.width - s3.width - 2*spacing, self.bounds.size.height - s1.height - s2.height - 2*spacing)
        
        yLabel.frame = CGRectMake(spacing, graphFrame.origin.y+(graphFrame.size.height-s3.height)/2.0, s3.width, s3.height)
    }
    
    func animateFrame(frame: CGRect) {
        self.layoutIfNeeded()
        UIView.animateWithDuration(0.15, animations: {
            self.frame = frame
            self.layoutIfNeeded()
        })
    }
}
