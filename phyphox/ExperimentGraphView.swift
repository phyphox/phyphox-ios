//
//  ExperimentGraphView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit
import OpenGLES

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
    
    private var min: GLpoint?
    private var max: GLpoint?
    
    private let glGraph: GLGraphView
    private let gridView: GraphGridView
    
    var queue: dispatch_queue_t!
    
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
    
    func getTicks(min: Double, max: Double, maxTicks: Int, log: Bool) -> [Double]? {
        if max <= min || !isfinite(min) || !isfinite(max) {
            return nil
        }
        
        if (log) {
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
        
        dispatch_async(queue) { () -> Void in
            autoreleasepool({ () -> () in
                var xValues: GraphValueSource
                let yValues = self.descriptor.yInputBuffer.graphValueSource
                
                var trashedCount = self.descriptor.yInputBuffer.trashedCount
                
                var count = yValues.count
                
                if count == 0 {
                    return
                }
                
                if let xBuf = self.descriptor.xInputBuffer {
                    xValues = xBuf.graphValueSource
                    
                    count = Swift.min(xValues.count, count)
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
                    
                    xValues = GraphFixedValueSource(array: self.lastIndexXArray!)
                }
                
                if count > 1 {
                    var maxX: GLfloat = -Float.infinity
                    var minX: GLfloat = Float.infinity
                    
                    var maxY: GLfloat = -Float.infinity
                    var minY: GLfloat = Float.infinity
                    
                    var actualMaxX = -Double.infinity
                    var actualMinX = Double.infinity
                    
                    var actualMaxY = -Double.infinity
                    var actualMinY = Double.infinity
                    
                    let count = Swift.min(xValues.count, yValues.count)
                    
                    var points: [GLpoint] = []
                    points.reserveCapacity(count)
                    
                    var lastX = -Double.infinity
                    
                    let logX = self.descriptor.logX
                    let logY = self.descriptor.logY
                    
                    for i in 0..<count {
                        let rawX = xValues[i]
                        let rawY = yValues[i]
                        
                        guard rawX != nil && rawY != nil else {
                            break
                        }
                        
                        if rawX! < lastX {
                            print("x value is smaller than previous value!")
                        }
                        
                        lastX = rawX!
                        
                        let unwrappedX = rawX!
                        let unwrappedY = rawY!
                        
                        if logX {
                            if unwrappedX < actualMinX {
                                actualMinX = unwrappedX
                            }
                            
                            if unwrappedX > actualMinX {
                                actualMaxX = unwrappedX
                            }
                        }
                        
                        if logY {
                            if unwrappedY < actualMinY {
                                actualMinY = unwrappedY
                            }
                            
                            if unwrappedY > actualMinY {
                                actualMaxY = unwrappedY
                            }
                        }
                        
                        let x = GLfloat((self.descriptor.logX ? log(unwrappedX) : unwrappedX))
                        let y = GLfloat((self.descriptor.logY ? log(unwrappedY) : unwrappedY))
                        
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
                    
                    if !logX {
                        actualMinX = Double(minX)
                        actualMaxX = Double(maxX)
                    }
                    
                    if !logY {
                        actualMinY = Double(minY)
                        actualMaxY = Double(maxY)
                    }
                    
                    self.min = GLpoint(x: minX, y: minY)
                    self.max = GLpoint(x: maxX, y: maxY)
                    
                    //                        let xTicks = ExperimentManager.sharedInstance().gridCalculator.search(Double(self.min!.x), dmax: Double(self.max!.x), m: 5).getList()
                    //                        let yTicks = ExperimentManager.sharedInstance().gridCalculator.search(Double(self.min!.y), dmax: Double(self.max!.y), m: 5).getList()
                    
                    
                    let xTicks = self.getTicks(actualMinX, max: actualMaxX, maxTicks: 6, log: self.descriptor.logX)
                    let yTicks = self.getTicks(actualMinY, max: actualMaxY, maxTicks: 6, log: self.descriptor.logY)
                    
                    var mappedXTicks: [GraphGridLine]? = nil
                    var mappedYTicks: [GraphGridLine]? = nil
                    
                    if xTicks != nil {
                        mappedXTicks = xTicks!.map({ (val) -> GraphGridLine in
//                            if self.descriptor.logX {
//                                return GraphGridLine(absoluteValue: val, relativeValue: CGFloat(log((val-Double(self.min!.x))/Double(self.max!.x-self.min!.x))))
//                            }
//                            else {
                                return GraphGridLine(absoluteValue: val, relativeValue: CGFloat((val-Double(self.min!.x))/Double(self.max!.x-self.min!.x)))
//                            }
                        })
                    }
                    
                    if yTicks != nil {
                        mappedYTicks = yTicks!.map({ (val) -> GraphGridLine in
//                            if self.descriptor.logY {
//                                return GraphGridLine(absoluteValue: val, relativeValue: CGFloat(log((val-Double(self.min!.y))/Double(self.max!.y-self.min!.y))))
//                            }
//                            else {
                                return GraphGridLine(absoluteValue: val, relativeValue: CGFloat((val-Double(self.min!.y))/Double(self.max!.y-self.min!.y)))
//                            }
                        })
                    }
                    
                    dispatch_sync(dispatch_get_main_queue(), { () -> Void in
                        self.gridView.grid = GraphGrid(xGridLines: mappedXTicks, yGridLines: mappedYTicks)
                        
                        self.glGraph.setPoints(points, min: self.min!, max: self.max!)
                        
                        self.setNeedsLayout()
                    });
                }
            })
            
            self.hasUpdateBlockEnqueued = false
        }
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

