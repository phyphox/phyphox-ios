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

final class ExperimentGraphView: ExperimentViewModule<GraphViewDescriptor>, DataBufferObserver {
    typealias T = GraphViewDescriptor
    
    private let xLabel: UILabel
    private let yLabel: UILabel
    
    private let glGraph: GLGraphView
    private let gridView: GraphGridView
    
    private var maxX: Double
    private var minX: Double
    private var maxY: Double
    private var minY: Double
    
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
            
            for (i, set) in dataSets.enumerate() {
                let maxPoint = set.bounds.max
                let minPoint = set.bounds.min
                
                if i == 0 {
                    if maxPoint.x > maxX {
                        maxX = maxPoint.x
                    }
                }
                else {
                    maxX += maxPoint.x-minPoint.x //add delta
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
    
    private var points: [GraphPoint<GLfloat>]? {
        if dataSets.count > 1 {
            var p: [GraphPoint<GLfloat>] = []
            
            var xAdd: GLfloat = 0.0
            
            for set in dataSets {
                let max = set.bounds.max
                let min = set.bounds.min
                
                if xAdd > 0 {
                    p.appendContentsOf(set.data.map({ (p) -> GraphPoint<GLfloat> in
                        return GraphPoint(x: p.x+xAdd, y: p.y)
                    }))
                }
                else {
                    p.appendContentsOf(set.data)
                }
                
                xAdd += GLfloat(max.x-min.x)
            }
            
            return p
        }
        else {
            return dataSets.first?.data
        }
    }
    
    required init(descriptor: GraphViewDescriptor) {
        self.maxX = -Double.infinity
        self.minX = Double.infinity
        
        self.maxY = -Double.infinity
        self.minY = Double.infinity
        
        glGraph = GLGraphView()
        glGraph.drawDots = descriptor.drawDots
        var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
        
        kHighlightColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        glGraph.lineColor = GLcolor(r: Float(r), g: Float(g), b: Float(b), a: Float(a))
        
        gridView = GraphGridView()
        gridView.gridInset = CGPoint(x: 25.0, y: 25.0)
        gridView.gridOffset = CGPointMake(0.0, -4.0)
        
        func makeLabel(text: String?) -> UILabel {
            let l = UILabel()
            l.text = text
            
            l.font = UIFont.preferredFontForTextStyle(UIFontTextStyleCaption1)
            
            return l
        }
        
        xLabel = makeLabel(descriptor.localizedXLabel)
        yLabel = makeLabel(descriptor.localizedYLabel)
        yLabel.transform = CGAffineTransformMakeRotation(-CGFloat(M_PI/2.0))
        
        super.init(descriptor: descriptor)
        
        addSubview(gridView)
        addSubview(glGraph)
        addSubview(xLabel)
        addSubview(yLabel)
        
        descriptor.yInputBuffer.addObserver(self)
    }
    
    func dataBufferUpdated(buffer: DataBuffer) {
        setNeedsUpdate()
    }
    
    //MARK - Graph
    func getTicks(min: Double, max: Double, maxTicks: Int) -> [Double]? {
        if max <= min || !isfinite(min) || !isfinite(max) {
            return nil
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
        
        var tickLocations = [Double]()
        tickLocations.reserveCapacity(maxTicks)
        
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
                
                switch self.descriptor.scaleMinX {
                case GraphViewDescriptor.scaleMode.auto:
                    self.minX = Double.infinity
                case GraphViewDescriptor.scaleMode.extend:
                break
                case GraphViewDescriptor.scaleMode.fixed:
                    self.minX = Double(self.descriptor.minX)
                }
                
                switch self.descriptor.scaleMaxX {
                case GraphViewDescriptor.scaleMode.auto:
                    self.maxX = -Double.infinity
                case GraphViewDescriptor.scaleMode.extend:
                    break
                case GraphViewDescriptor.scaleMode.fixed:
                    self.maxX = Double(self.descriptor.maxX)
                }
                
                switch self.descriptor.scaleMinY {
                case GraphViewDescriptor.scaleMode.auto:
                    self.minY = Double.infinity
                case GraphViewDescriptor.scaleMode.extend:
                    break
                case GraphViewDescriptor.scaleMode.fixed:
                    self.minY = Double(self.descriptor.minY)
                }
                
                switch self.descriptor.scaleMaxY {
                case GraphViewDescriptor.scaleMode.auto:
                    self.maxY = -Double.infinity
                case GraphViewDescriptor.scaleMode.extend:
                    break
                case GraphViewDescriptor.scaleMode.fixed:
                    self.maxY = Double(self.descriptor.maxY)
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
                    
                    if x < self.minX && self.descriptor.scaleMinX != GraphViewDescriptor.scaleMode.fixed {
                        self.minX = x
                    }
                    
                    if x > self.maxX && self.descriptor.scaleMaxX != GraphViewDescriptor.scaleMode.fixed {
                        self.maxX = x
                    }
                    
                    if y < self.minY && self.descriptor.scaleMinY != GraphViewDescriptor.scaleMode.fixed {
                        self.minY = y
                    }
                    
                    if y > self.maxY && self.descriptor.scaleMaxY != GraphViewDescriptor.scaleMode.fixed {
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
                
                let xTicks = self.getTicks(self.minX, max: self.maxX, maxTicks: 6)
                let yTicks = self.getTicks(self.minY, max: self.maxY, maxTicks: 4)
                
                var mappedXTicks: [GraphGridLine]? = nil
                var mappedYTicks: [GraphGridLine]? = nil
                
                if xTicks != nil {
                    mappedXTicks = xTicks!.map({ (val) -> GraphGridLine in
                        return GraphGridLine(absoluteValue: logX ? round(exp(val)) : val, relativeValue: CGFloat((val-self.minX)/(self.maxX-self.minX)))
                    })
                }
                
                if yTicks != nil {
                    mappedYTicks = yTicks!.map({ (val) -> GraphGridLine in
                        return GraphGridLine(absoluteValue: logY ? round(exp(val)) : val, relativeValue: CGFloat((val-self.minY)/(self.maxY-self.minY)))
                    })
                }
                
                let finalPoints = self.points!
                
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
        
        self.glGraph.setPoints(nil, min: nil, max: nil)
    }
    
    //Mark - General UI
    
    override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(size.width, Swift.min(size.width/descriptor.aspectRatio, size.height))
    }
    
    var graphFrame: CGRect {
        return gridView.insetRect
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let spacing: CGFloat = 1.0
        
        let s1 = label.sizeThatFits(self.bounds.size)
        label.frame = CGRectMake((self.bounds.size.width-s1.width)/2.0, spacing, s1.width, s1.height)
        
        let s2 = xLabel.sizeThatFits(self.bounds.size)
        xLabel.frame = CGRectMake((self.bounds.size.width-s2.width)/2.0, self.bounds.size.height-s2.height-spacing, s2.width, s2.height)
        
        let s3 = CGSizeApplyAffineTransform(yLabel.sizeThatFits(self.bounds.size), yLabel.transform)
        yLabel.frame = CGRectMake(spacing+5.0, (self.bounds.size.height-s3.height)/2.0-4.0, s3.width, s3.height)
        
        gridView.frame = bounds
        glGraph.frame = graphFrame
    }
}
