//
//  ExperimentGraphView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

protocol GraphValueSource {
    subscript(index: Int) -> Double? { get }
    var count: Int { get }
    var last: Double? { get }
}

struct GraphGrid {
    let xGridLines: [GraphGridLine]?
    let yGridLines: [GraphGridLine]?
}

struct GraphGridLine {
    let absoluteValue: Double
    let relativeValue: CGFloat
}

final class GraphFixedValueSource: GraphValueSource {
    let array: [Double]
    
    init(array: [Double]) {
        self.array = array
    }
    
    subscript(index: Int) -> Double? {
        return array[index]
    }
    
    var last: Double? {
        get {
            return array.last
        }
    }
    
    var count: Int {
        get {
            return array.count
        }
    }
}

public class ExperimentGraphView: ExperimentViewModule<GraphViewDescriptor>, DataBufferObserver {
    typealias T = GraphViewDescriptor
    
    private let xLabel: UILabel
    private let yLabel: UILabel
    
    private let glGraph: GLGraphView
    private let gridView: GraphGridView
    
    var queue: dispatch_queue_t!
    
    //((min, max), data)
    var dataSets: [((GLpoint, GLpoint), [GLpoint])] = []
    
    required public init(descriptor: GraphViewDescriptor) {
        glGraph = GLGraphView(frame: .zero)
        gridView = GraphGridView()
        glGraph.drawDots = descriptor.drawDots
        
        func makeLabel(text: String?) -> UILabel {
            let l = UILabel()
            l.text = text
            
           l.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
            
            return l
        }
        
        xLabel = makeLabel(descriptor.xLabel)
        yLabel = makeLabel(descriptor.yLabel)
        yLabel.transform = CGAffineTransformMakeRotation(-CGFloat(M_PI/2.0))
        
        super.init(descriptor: descriptor)
        
        addSubview(gridView)
        addSubview(glGraph)
        addSubview(xLabel)
        addSubview(yLabel)
        
        descriptor.yInputBuffer.addObserver(self)
    }
    
    func getTicks(min mi: Double, max ma: Double, maxTicks: Int, log: Bool) -> [Double]? {
        if ma <= mi || !isfinite(mi) || !isfinite(ma) {
            return nil
        }
        
        if (log) {
            let min = exp(mi)
            let max = exp(ma)
            
            if (min < 0) {
                return nil
            }
            
            let range = Int(floor(max)-ceil(min))
            
            if (range < 1) {
                return nil
            }
            
            var magStep = 1;
            while (range+1 > maxTicks * magStep) {
                magStep += 1
            }
            
            var first = ceil(min)
            
            var ticks = [Double]()
            ticks.reserveCapacity((range+1)/magStep)
            
            for _ in 0..<(range+1)/magStep {
                ticks.append(Darwin.log(first))
                first *= M_E
            }
            
            return ticks;
        }
        
        let max = ma
        let min = mi
        
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
        
        let stepCount = Int(ceil(range/step))
        
        let first = ceil(min/step)*step
        
        var tickLocations = [Double]()
        tickLocations.reserveCapacity(stepCount)
        
        for i in 0..<stepCount {
            let s = first+Double(i)*step
            
            if s >= max {
                break
            }
            
            tickLocations.append(s)
        }
        
        return tickLocations
    }

    
    func dataBufferUpdated(buffer: DataBuffer) {
        setNeedsUpdate()
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    //MARK - Graph
    var graphFrame: CGRect {
        get {
            return CGRectInset(self.bounds, 25, 25)
        }
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
                
                if count == 0 {
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
                        return
                    }
                    
                    xValues = self.lastIndexXArray!
                }
                
                if count > 1 {
                    var maxX: GLfloat = -Float.infinity
                    var minX: GLfloat = Float.infinity
                    
                    var maxY: GLfloat = -Float.infinity
                    var minY: GLfloat = Float.infinity
                    
                    let count = Swift.min(xValues.count, yValues.count)
                    
                    var points: [GLpoint] = []
                    points.reserveCapacity(count)
                    
                    var lastX = -Double.infinity
                    
                    let logX = self.descriptor.logX
                    let logY = self.descriptor.logY
                    
                    for i in 0..<count {
                        let rawX = xValues[i]
                        let rawY = yValues[i]
                        
//                        guard rawX != nil && rawY != nil else {
//                            break
//                        }
                        
                        if rawX < lastX {
                            print("x value is smaller than previous value!")
                        }
                        
                        lastX = rawX
                        
                        let x = GLfloat((logX ? log(rawX) : rawX))
                        let y = GLfloat((logY ? log(rawY) : rawY))
                        
                        guard isfinite(x) && isfinite(y) else {
                            #if DEBUG
                                print("Ignoring non finite value in graph (\(x) or \(y))")
                            #endif
                            continue
                        }
                        
                        if x < minX {
                            minX = x
                        }
                        
                        if x > maxX {
                            maxX = x
                        }
                        
                        if y < minY {
                            minY = y
                        }
                        
                        if y > maxY {
                            maxY = y
                        }
                        
                        points.append(GLpoint(x: x, y: y))
                    }
                    
                    let min = GLpoint(x: minX, y: minY)
                    let max = GLpoint(x: maxX, y: maxY)
                    
                    if self.dataSets.count >= Int(self.descriptor.history) {
                        self.dataSets.removeFirst()
                    }
                    
                    self.dataSets.append(((min, max), points))
                    
                    let history = self.descriptor.history > 1
                    
                    let totalMin = (history ? self.min : min)
                    let totalMax = (history ? self.max : max)
                    
                    let xTicks = self.getTicks(min: Double(totalMin.x), max: Double(totalMax.x), maxTicks: 6, log: self.descriptor.logX)
                    let yTicks = self.getTicks(min: Double(totalMin.y), max: Double(totalMax.y), maxTicks: 4, log: self.descriptor.logY)
                    
                    var mappedXTicks: [GraphGridLine]? = nil
                    var mappedYTicks: [GraphGridLine]? = nil
                    
                    if xTicks != nil {
                        mappedXTicks = xTicks!.map({ (val) -> GraphGridLine in
//                            if self.descriptor.logX {
//                                return GraphGridLine(absoluteValue: val, relativeValue: CGFloat(log((val-Double(self.min!.x))/Double(self.max!.x-self.min!.x))))
//                            }
//                            else {
                                return GraphGridLine(absoluteValue: val, relativeValue: CGFloat((val-Double(totalMin.x))/Double(totalMax.x-totalMin.x)))
//                            }
                        })
                    }
                    
                    if yTicks != nil {
                        mappedYTicks = yTicks!.map({ (val) -> GraphGridLine in
//                            if self.descriptor.logY {
//                                return GraphGridLine(absoluteValue: val, relativeValue: CGFloat(log((val-Double(self.min!.y))/Double(self.max!.y-self.min!.y))))
//                            }
//                            else {
                                return GraphGridLine(absoluteValue: val, relativeValue: CGFloat((val-Double(totalMin.y))/Double(totalMax.y-totalMin.y)))
//                            }
                        })
                    }
                    
                    mainThread({
                        self.gridView.grid = GraphGrid(xGridLines: mappedXTicks, yGridLines: mappedYTicks)
                        
                        self.glGraph.setPoints((history ? self.points : points), min: totalMin, max: totalMax)
                        
                        self.setNeedsLayout()
                    });
                }
            })
            
            self.hasUpdateBlockEnqueued = false
        }
    }
    
    var max: GLpoint {
        get {
            var maxX: GLfloat = -Float.infinity
            var maxY: GLfloat = -Float.infinity
            
            for (i, set) in dataSets.enumerate() {
                let maxPoint = set.0.1
                let minPoint = set.0.0
                
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
            
            return GLpoint(x: maxX, y: maxY)
        }
    }
    
    var min: GLpoint {
        get {
            var minX: GLfloat = Float.infinity
            var minY: GLfloat = Float.infinity
            
            for set in dataSets {
                let minPoint = set.0.0
                
                if minPoint.x < minX {
                    minX = minPoint.x
                }
                
                if minPoint.y < minY {
                    minY = minPoint.y
                }
            }
            
            return GLpoint(x: minX, y: minY)
        }
    }
    
    var points: [GLpoint] {
        var p: [GLpoint] = []
        
        var xAdd: GLfloat = 0.0
        
        for set in dataSets {
            let max = set.0.1
            let min = set.0.0
            
            if xAdd > 0 {
                p.appendContentsOf(set.1.map({ (p) -> GLpoint in
                    return GLpoint(x: p.x+xAdd, y: p.y)
                }))
            }
            else {
                p.appendContentsOf(set.1)
            }
            
            xAdd += max.x-min.x
        }
        
        return p
    }
    
    //Mark - General UI
    
    public override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(size.width, Swift.min(size.width/descriptor.aspectRatio, size.height))
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        let spacing: CGFloat = 2.0
        
        let s1 = label.sizeThatFits(self.bounds.size)
        label.frame = CGRectMake((self.bounds.size.width-s1.width)/2.0, spacing, s1.width, s1.height)
        
        let s2 = xLabel.sizeThatFits(self.bounds.size)
        xLabel.frame = CGRectMake((self.bounds.size.width-s2.width)/2.0, self.bounds.size.height-s2.height-spacing, s2.width, s2.height)
        
        let s3 = CGSizeApplyAffineTransform(yLabel.sizeThatFits(self.bounds.size), yLabel.transform)
        yLabel.frame = CGRectMake(spacing, (self.bounds.size.height-s3.height)/2.0, s3.width, s3.height)
        
        gridView.frame = graphFrame
        glGraph.frame = graphFrame
    }
}

