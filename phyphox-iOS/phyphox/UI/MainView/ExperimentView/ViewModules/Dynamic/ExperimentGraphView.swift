//
//  ExperimentGraphView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit

final class ExperimentGraphView: DisplayLinkedView, DynamicViewModule, DescriptorBoundViewModule, GraphViewModule {
    let descriptor: GraphViewDescriptor

    var active = false {
        didSet {
            linked = active
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
        
        xLabel = makeLabel(descriptor.localizedXLabel)
        yLabel = makeLabel(descriptor.localizedYLabel)
        xLabel.textColor = kTextColor
        yLabel.textColor = kTextColor
        yLabel.transform = CGAffineTransform(rotationAngle: -CGFloat(Double.pi/2.0))
        
        super.init(frame: .zero)
        
        gridView.delegate = self

        addSubview(label)
        addSubview(gridView)
        addSubview(glGraph)
        addSubview(xLabel)
        addSubview(yLabel)

        registerForUpdatesFromBuffer(descriptor.yInputBuffer)
        if let xBuffer = descriptor.xInputBuffer {
            registerForUpdatesFromBuffer(xBuffer)
        }
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

        let xMinStrict = descriptor.scaleMinX == .fixed
        let xMaxStrict = descriptor.scaleMaxX == .fixed
        let yMinStrict = descriptor.scaleMinY == .fixed
        let yMaxStrict = descriptor.scaleMaxY == .fixed

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

            if x < minX {
                if xMinStrict {
                    continue
                }
                else {
                    minX = x
                }
            }

            if x > maxX {
                if xMaxStrict {
                    continue
                }
                else {
                    maxX = x
                }
            }

            if y < minY {
                if yMinStrict {
                    continue
                }
                else {
                    minY = y
                }
            }

            if y > maxY {
                if yMaxStrict {
                    continue
                }
                else {
                    maxY = y
                }
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

    override func display() {
        if wantsUpdate {
            wantsUpdate = false
            update()
        }
    }

    private func update() {
        guard superview != nil && window != nil else { return }

        queue.async { [weak self] in
            autoreleasepool {
                self?.runUpdate()
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
