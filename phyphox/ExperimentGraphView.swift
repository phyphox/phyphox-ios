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

class GraphFixedValueSource: GraphValueSource {
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
    
    let xLabel: UILabel
    let yLabel: UILabel
    
    var queue: dispatch_queue_t!
    
    let glGraph: GLGraphView
    
    required public init(descriptor: GraphViewDescriptor) {
        glGraph = GLGraphView(frame: .zero)
        
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
        
        addSubview(glGraph)
        addSubview(xLabel)
        addSubview(yLabel)
        
        descriptor.yInputBuffer.addObserver(self)
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
                    
                    count = min(xValues.count, count)
                    trashedCount = min(xBuf.trashedCount, trashedCount)
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
                    
                    let count = min(xValues.count, yValues.count)
                    
                    var points: [GLpoint] = []
                    
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
                        
                        let x = GLfloat(rawX!)
                        let y = GLfloat(rawY!)
                        
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
                        self.glGraph.setPoints(points, length: UInt(count), min: GLpoint(x: minX, y: minY), max: GLpoint(x: maxX, y: maxY))
                    });
                }
            })
            
            self.hasUpdateBlockEnqueued = false
        }
    }
    
    //Mark - General UI
    
    public override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(size.width, min(size.width/descriptor.aspectRatio, size.height))
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
        
        glGraph.frame = graphFrame
    }
}

