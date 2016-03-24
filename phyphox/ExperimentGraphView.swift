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
    private let gridView: ExperimentGraphGridView
    
    var queue: dispatch_queue_t!
    
    required public init(descriptor: GraphViewDescriptor) {
        glGraph = GLGraphView(frame: .zero)
        gridView = ExperimentGraphGridView()
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
    
    func getTics(min: Double, max: Double, maxTics: Int, log: Bool) -> [Double]? {
        if max <= min || !isfinite(min) || !isfinite(max) {
            return nil //Invalid axis. No tics
        }
        
        if (log) { //Logarithmic axis. This needs logic of its own...
            if (min < 0) {//negative values do not work for logarithmic axes
                return nil
            }
            let range = Int(floor(max)-ceil(min))
            
            //we will just set up tics at powers of ten: 0.1, 1, 10, 100 etc.
            if (range < 1) {//Range to short for this naive tic algorithm
                return nil
            }
            
            var magStep = 1; //If we cover huge scales we might want to do larger steps...
            while (range+1 > maxTics * magStep) {//Do we have more than max tics? Increase step size then.
                magStep += 1
            }
            
            var first = ceil(min) //The first tic above min
            
            var tics = [Double]() //The array to hold the tics
            tics.reserveCapacity((range+1)/magStep)
            
            for _ in 0..<(range+1)/magStep { //Fill the array with powers of ten
                tics.append(first)
                first *= 10
            }
            
            return tics; //Done
        }
        
        let range = max-min
        
        let stepFactor = pow(10.0, floor(log10(range))-1) //First estimate how large the steps between our tics should be as a power of ten
        var step = 1.0 //The finer step size within the power of ten
        let steps = Int(range/stepFactor) //How many steps would there be with step times stepfactor?
        
        
        //Depending on how many steps we would have, increase the step factor to stay within maxTics
        if (steps <= maxTics) {
            step = 1*stepFactor
        }
        else if (steps <= maxTics * 2) {
            step = 2*stepFactor
        }
        else if (steps <= maxTics * 5) {
            step = 5*stepFactor
        }
        else if (steps <= maxTics * 10) {
            step = 10*stepFactor
        }
        else if (steps <= maxTics * 20) {
            step = 20*stepFactor
        }
        else if (steps <= maxTics * 50) {
            step = 50*stepFactor
        }
        else if (steps <= maxTics * 100) {
            step = 100*stepFactor
        }
        
        //ok how many (integer) steps exactly?
        let iSteps = Int(range/step)
        
        let first = ceil(min/step)*step //Value of the first tic
        var tics = [Double]() //Array to hold the tics
        tics.reserveCapacity(iSteps)
        
        //Generate the tics by stepping up from the first tic
        for i in 0..<iSteps {
            tics.append(first+Double(i)*step);
        }
        
        return tics; //Done
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
                    
                    let count = Swift.min(xValues.count, yValues.count)
                    
                    var points: [GLpoint] = []
                    points.reserveCapacity(count)
                    
                    var lastX = -Double.infinity
                    
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
                        
                        let x = GLfloat((self.descriptor.logX ? log(rawX!) : rawX!))
                        let y = GLfloat((self.descriptor.logY ? log(rawY!) : rawY!))
                        
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
                    
                    dispatch_sync(dispatch_get_main_queue(), { () -> Void in
                        self.min = GLpoint(x: minX, y: minY)
                        self.max = GLpoint(x: maxX, y: maxY)
                        
                        let xTicks = self.getTics(Double(self.min!.x), max: Double(self.max!.x), maxTics: 6, log: self.descriptor.logX)
                        let yTicks = self.getTics(Double(self.min!.y), max: Double(self.max!.y), maxTics: 6, log: self.descriptor.logY)
        
                        var mappedXTicks: [GraphGridLine]? = nil
                        var mappedYTicks: [GraphGridLine]? = nil
                        
                        if xTicks != nil {
                            mappedXTicks = xTicks!.map({ (val) -> GraphGridLine in
                                if self.descriptor.logX {
                                    return GraphGridLine(absoluteValue: val, relativeValue: CGFloat(log((val-Double(self.min!.x))/Double(self.max!.x-self.min!.x))))
                                }
                                else {
                                    return GraphGridLine(absoluteValue: val, relativeValue: CGFloat((val-Double(self.min!.x))/Double(self.max!.x-self.min!.x)))
                                }
                            })
                        }
                        
                        if yTicks != nil {
                            mappedYTicks = yTicks!.map({ (val) -> GraphGridLine in
                                if self.descriptor.logY {
                                    return GraphGridLine(absoluteValue: val, relativeValue: CGFloat(log((val-Double(self.min!.y))/Double(self.max!.y-self.min!.y))))
                                }
                                else {
                                    return GraphGridLine(absoluteValue: val, relativeValue: CGFloat((val-Double(self.min!.y))/Double(self.max!.y-self.min!.y)))
                                }
                            })
                        }
                        
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

