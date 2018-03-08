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
    let xGridLines: [GraphGridLine]
    let yGridLines: [GraphGridLine]
}

struct GraphGridLine {
    let absoluteValue: Double
    let relativeValue: CGFloat
}

final class ExperimentGraphView: ExperimentViewModule<GraphViewDescriptor>, GraphViewModuleProtocol {
    private let xLabel: UILabel
    private let yLabel: UILabel
    
    private let glGraph: GLGraphView
    private let gridView: GraphGridView
    
    private var maxX: Double
    private var minX: Double
    private var maxY: Double
    private var minY: Double

    var queue: DispatchQueue?
    
    private var dataSets: [(bounds: (min: GraphPoint<Double>, max: GraphPoint<Double>), data: [GraphPoint<GLfloat>])] = []
    
    private func addDataSet(_ set: (bounds: (min: GraphPoint<Double>, max: GraphPoint<Double>), data: [GraphPoint<GLfloat>])) {
        if dataSets.count >= Int(descriptor.history) {
            dataSets.removeFirst()
        }
        
        dataSets.append(set)
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
        return dataSets.map { $0.data }
    }
    
    required init?(descriptor: GraphViewDescriptor) {
        maxX = -Double.infinity
        minX = Double.infinity
        
        maxY = -Double.infinity
        minY = Double.infinity

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
        
        xLabel = makeLabel(descriptor.localizedXLabel)
        yLabel = makeLabel(descriptor.localizedYLabel)
        xLabel.textColor = kTextColor
        yLabel.textColor = kTextColor
        yLabel.transform = CGAffineTransform(rotationAngle: -CGFloat(Double.pi/2.0))
        
        super.init(descriptor: descriptor)
        
        gridView.delegate = self
        
        addSubview(gridView)
        addSubview(glGraph)
        addSubview(xLabel)
        addSubview(yLabel)

        registerInputBuffer(descriptor.yInputBuffer)
        if let xBuffer = descriptor.xInputBuffer {
            registerInputBuffer(xBuffer)
        }
    }
    
    //MARK - Graph
    
    private var lastIndexXArray: [Double]?
    private var lastCount: Int?
    
    private var hasUpdateBlockEnqueued = false

    private func runUpdate() {
        defer {
            hasUpdateBlockEnqueued = false
        }

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

        switch descriptor.scaleMinX {
        case .auto:
            minX = Double.infinity
        case .extend:
            break
        case .fixed:
            minX = Double(descriptor.minX)
        }

        switch descriptor.scaleMaxX {
        case .auto:
            maxX = -Double.infinity
        case .extend:
            break
        case .fixed:
            maxX = Double(descriptor.maxX)
        }

        switch descriptor.scaleMinY {
        case .auto:
            minY = Double.infinity
        case .extend:
            break
        case .fixed:
            minY = Double(descriptor.minY)
        }

        switch descriptor.scaleMaxY {
        case .auto:
            maxY = -Double.infinity
        case .extend:
            break
        case .fixed:
            maxY = Double(descriptor.maxY)
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

            if x < minX && descriptor.scaleMinX != .fixed {
                minX = x
            }

            if x > maxX && descriptor.scaleMaxX != .fixed {
                maxX = x
            }

            if y < minY && descriptor.scaleMinY != .fixed {
                minY = y
            }

            if y > maxY && descriptor.scaleMaxY != .fixed {
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

        let min = self.min!
        let max = self.max!

        minX = min.x
        maxX = max.x

        minY = min.y
        maxY = max.y

        let xTicks = ExperimentGraphUtilities.getTicks(minX, max: maxX, maxTicks: 6, log: logX)
        let yTicks = ExperimentGraphUtilities.getTicks(minY, max: maxY, maxTicks: 6, log: logY)

        let mappedXTicks = xTicks.map({ (val) -> GraphGridLine in
            return GraphGridLine(absoluteValue: val, relativeValue: CGFloat(((logX ? log(val) : val)-minX)/(maxX-minX)))
        })

        let mappedYTicks = yTicks.map({ (val) -> GraphGridLine in
            return GraphGridLine(absoluteValue: val, relativeValue: CGFloat(((logY ? log(val) : val)-minY)/(maxY-minY)))
        })

        let finalPoints = self.points

        mainThread {
            self.gridView.grid = GraphGrid(xGridLines: mappedXTicks, yGridLines: mappedYTicks)
            self.glGraph.setPoints(finalPoints, min: min, max: max)
        }
    }

    override func update() {
        guard superview != nil && window != nil else { return }

        if self.queue == nil {
            print("Graph queue not set!")
        }

        let queue = self.queue ?? DispatchQueue.global(qos: .utility)
        
        queue.async { [weak self] in
            guard let strongSelf = self, !strongSelf.hasUpdateBlockEnqueued else { return }
            strongSelf.hasUpdateBlockEnqueued = true

            autoreleasepool {
                strongSelf.runUpdate()
            }
        }
    }
    
    func clearData() {
        dataSets.removeAll()
        clearGraph()
    }
    
    private func clearGraph() {
        maxX = -Double.infinity
        minX = Double.infinity
        
        maxY = -Double.infinity
        minY = Double.infinity
        
        gridView.grid = nil
        
        lastIndexXArray = nil
        
        glGraph.setPoints([], min: .zero, max: .zero)
    }
    
    //Mark - General UI
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let s1 = label.sizeThatFits(bounds.size)

        return CGSize(width: size.width, height: Swift.min(size.width/descriptor.aspectRatio + s1.height + 1.0, size.height))
    }
    
    private var graphFrame: CGRect {
        return gridView.insetRect.offsetBy(dx: gridView.frame.origin.x, dy: gridView.frame.origin.y)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let spacing: CGFloat = 1.0
        
        let s1 = label.sizeThatFits(bounds.size)
        label.frame = CGRect(x: (bounds.size.width-s1.width)/2.0, y: spacing, width: s1.width, height: s1.height)
        
        let s2 = xLabel.sizeThatFits(bounds.size)
        xLabel.frame = CGRect(x: (bounds.size.width-s2.width)/2.0, y: bounds.size.height-s2.height-spacing, width: s2.width, height: s2.height)
        
        let s3 = yLabel.sizeThatFits(bounds.size).applying(yLabel.transform)
        
        gridView.frame = CGRect(x: s3.width + spacing, y: s1.height+spacing, width: bounds.size.width - s3.width - 2*spacing, height: bounds.size.height - s1.height - s2.height - 2*spacing)
        
        yLabel.frame = CGRect(x: spacing, y: graphFrame.origin.y+(graphFrame.size.height-s3.height)/2.0, width: s3.width, height: s3.height)
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
