//
//  ExperimentUnboundedFunctionGraphView.swift
//  phyphox
//
//  Created by Jonas Gessner on 07.03.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import UIKit

protocol GraphViewModuleProtocol {
    func clearData()
}

typealias GraphViewModule = ExperimentViewModule<GraphViewDescriptor> & GraphViewModuleProtocol

struct RangedGraphPoint<T: Comparable & Numeric> {
    let xRange: ClosedRange<T>
    let yRange: ClosedRange<T>
}

private protocol GraphPointCollection {
    var logX: Bool { get }
    var logY: Bool { get }

    var points: [RangedGraphPoint<GLfloat>] { get set }

    var currentStride: Int { get set }
    var currentOffsetFromLastPoint: Int { get set }

    var count: Int { get }
    var representedPointCount: Int { get }

    mutating func append<S: Sequence>(_ newPoints: S) -> (replacedPointCount: Int, appendedPointCount: Int) where S.Element == (Double, Double)

    mutating func factorStride(by factor: Int)

    mutating func commitPoint(_ point: RangedGraphPoint<GLfloat>)

    mutating func removeAll()
}

extension GraphPointCollection {
    var count: Int {
        return points.count
    }

    var representedPointCount: Int {
        if currentOffsetFromLastPoint > 0 {
            return (points.count - 1) * currentStride + currentOffsetFromLastPoint
        }
        else {
            return points.count * currentStride
        }
    }

    mutating func removeAll() {
        currentStride = 1
        currentOffsetFromLastPoint = 0
        points.removeAll()
    }

    mutating func commitPoint(_ point: RangedGraphPoint<GLfloat>) {
        points.append(point)
    }

    mutating func append<S: Sequence>(_ newPoints: S) -> (replacedPointCount: Int, appendedPointCount: Int) where S.Element == (Double, Double) {
        var currentPoint = currentOffsetFromLastPoint == 0 ? nil : points.popLast()

        let replacedPointCount = currentOffsetFromLastPoint == 0 ? 0 : 1
        var addedPointCount = 0

        for (rawX, rawY) in newPoints {
            let x = GLfloat(logX ? log(rawX) : rawX)
            let y = GLfloat(logY ? log(rawY) : rawY)

            if currentOffsetFromLastPoint == currentStride, let point = currentPoint {
                commitPoint(point)
                addedPointCount += 1
                currentPoint = nil
                currentOffsetFromLastPoint = 0
            }

            if currentOffsetFromLastPoint == 0 {
                currentOffsetFromLastPoint = 1

                if !x.isFinite {
                    print("Error: Received NaN or inf in function graph. Function graph only supports finite values.")
                    continue
                }

                if !y.isFinite {
                    if currentPoint == nil {
                        currentPoint = RangedGraphPoint(xRange: x...x, yRange: 0...0)
                    }
                }
                else {
                    currentPoint = RangedGraphPoint(xRange: x...x, yRange: y...y)
                }
            }
            else if let point = currentPoint {
                let xRange = point.xRange.lowerBound...x
                let yRange = Swift.min(point.yRange.lowerBound, y)...Swift.max(point.yRange.upperBound, y)

                currentPoint = RangedGraphPoint(xRange: xRange, yRange: yRange)

                currentOffsetFromLastPoint += 1
            }
        }

        if let point = currentPoint {
            commitPoint(point)
            addedPointCount += 1
            currentOffsetFromLastPoint %= currentStride
        }

        return (replacedPointCount, Swift.max(addedPointCount - replacedPointCount, 0))
    }

    mutating func factorStride(by factor: Int) {
        print("Increase stride by \(factor)")

        let danglingPointCount = (points.count % factor)

        points = mergePoints(points, by: factor)

        let previousStride = currentStride

        currentStride *= factor

        // If there is no dangling point and the last point was not complete we have to increase the offset by the current stride (before updating it with the new factor), which is equal to the number of single points represented by one completed ranged point, times the number of points that were merged with the incomplete last point (factor - 1). The point created by merging the last `factor` points will also not be complete since the previous last point was incomplete.
        if danglingPointCount == 0 && currentOffsetFromLastPoint > 0 {
            currentOffsetFromLastPoint += (factor - 1) * previousStride
        }

        if danglingPointCount > 0 {
            // If the last point was complete the new offset is `number of dangling points * current stride (before updating it with the new factor)`. If the last point was incomplete the new offset is `oldOffset + current stride * (number of dangling points - 1)`
            if currentOffsetFromLastPoint == 0 {
                currentOffsetFromLastPoint = previousStride * danglingPointCount
            }
            else {
                currentOffsetFromLastPoint += previousStride * (danglingPointCount - 1)
            }
        }
    }

    private func mergeOrdered<C: RandomAccessCollection, T>(point: RangedGraphPoint<T>, with points: C) -> RangedGraphPoint<T> where C.Element == RangedGraphPoint<T> {
        let minX = point.xRange.lowerBound
        let maxX = points.last?.xRange.upperBound ?? point.xRange.upperBound

        var minY = point.yRange.lowerBound
        var maxY = point.yRange.upperBound

        points.forEach {
            minY = Swift.min(minY, $0.yRange.lowerBound)
            maxY = Swift.max(maxY, $0.yRange.upperBound)
        }

        return RangedGraphPoint(xRange: minX...maxX, yRange: minY...maxY)
    }

    private func mergePoints(_ points: [RangedGraphPoint<GLfloat>], by factor: Int) -> [RangedGraphPoint<GLfloat>] {
        var mergedPoints = [RangedGraphPoint<GLfloat>]()
        // Merge each group of `factor` points. If the number of points is not divisible by `factor` a number of "dangling" points remain that together form a new incomplete point
        let danglingPointCount = (points.count % factor)

        mergedPoints.reserveCapacity(points.count/factor + danglingPointCount)

        // Merge every `factor` points, including dangling points
        for i in stride(from: 0, to: points.count, by: factor) {
            let currentPoint = points[i]

            let nextPoints = points[i + 1..<Swift.min(i + factor, points.count)]

            let mergedPoint = mergeOrdered(point: currentPoint, with: nextPoints)

            mergedPoints.append(mergedPoint)
        }

        return mergedPoints
    }
}

private struct MainGraphPointCollection: GraphPointCollection {
    let logX: Bool
    let logY: Bool

    var points: [RangedGraphPoint<GLfloat>] = []

    var currentStride = 1
    var currentOffsetFromLastPoint = 0

    private(set) var maxX = -GLfloat.infinity
    private(set) var minX = GLfloat.infinity

    private(set) var maxY = -GLfloat.infinity
    private(set) var minY = GLfloat.infinity

    private(set) var longestStride: GLfloat = 0.0

    init(logX: Bool, logY: Bool) {
        self.logX = logX
        self.logY = logY
    }

    mutating func commitPoint(_ point: RangedGraphPoint<GLfloat>) {
        if let last = points.last {
            longestStride = Swift.max(longestStride, point.xRange.upperBound - last.xRange.lowerBound)
        }
        else {
            longestStride = Swift.max(longestStride, point.xRange.upperBound-point.yRange.lowerBound)
        }

        points.append(point)

        maxX = Swift.max(point.xRange.upperBound, maxX)
        minX = Swift.min(point.xRange.lowerBound, minX)

        maxY = Swift.max(point.yRange.upperBound, maxY)
        minY = Swift.min(point.yRange.lowerBound, minY)
    }

    mutating func removeAll() {
        currentStride = 1
        currentOffsetFromLastPoint = 0
        points.removeAll()

        maxX = -GLfloat.infinity
        minX = GLfloat.infinity
        maxY = -GLfloat.infinity
        minY = GLfloat.infinity
        longestStride = 0.0
    }
}

private struct GraphGraphPointCollection: GraphPointCollection {
    let logX: Bool
    let logY: Bool

    var points: [RangedGraphPoint<GLfloat>] = []

    var currentStride = 1
    var currentOffsetFromLastPoint = 0

    init(logX: Bool, logY: Bool) {
        self.logX = logX
        self.logY = logY
    }
}

private let maxPoints = 3000

/**
 Graph view used to display functions (where each x value is is related to exactly one y value) where the stream of incoming x values is in ascending order (descriptor.partialUpdate = true on the view descriptor) and no values are deleted (inputBuffer sizes are 0). The displayed history also has to be 1 (descriptor.history = 1).
 */
final class ExperimentUnboundedFunctionGraphView: ExperimentViewModule<GraphViewDescriptor>, GraphViewModuleProtocol {
    private let queue = DispatchQueue(label: "de.rwth-aachen.phyphox.graphview", qos: .userInitiated, attributes: [], autoreleaseFrequency: .inherit, target: nil)

    private let xLabel: UILabel
    private let yLabel: UILabel

    private let glGraph: GLRangedPointGraphView
    private let gridView: GraphGridView

    private var longestStride = 0.0

    required init?(descriptor: GraphViewDescriptor) {
        guard descriptor.partialUpdate && descriptor.history == 1 && descriptor.yInputBuffer.size == 0 && (descriptor.xInputBuffer?.size ?? 0) == 0 else { return nil }

        var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0

        descriptor.color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let lineColor = GLcolor(r: Float(r), g: Float(g), b: Float(b), a: Float(a))

        glGraph = GLRangedPointGraphView(drawDots: descriptor.drawDots, lineWidth: GLfloat(descriptor.lineWidth * (descriptor.drawDots ? 4.0 : 2.0)), lineColor: lineColor, maximumPointCount: maxPoints)
        glGraph.drawQuads = false

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

        wantsUpdatesWhenInactive = true

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

    private var mainPointCollection = MainGraphPointCollection(logX: false, logY: false)
   // private var graphPointCollection = GraphGraphPointCollection(logX: false, logY: false)

    private var hasUpdateBlockEnqueued = false

    private var lastxCount = 0
    private var lastyCount = 0

    private func runUpdate(graphWidth: Int) {
        defer {
            hasUpdateBlockEnqueued = false
        }

        let previousCount = mainPointCollection.representedPointCount

        var xValues: [Double]
        let yValues = descriptor.yInputBuffer.toArray()

        var xCount: Int
        let yCount = descriptor.yInputBuffer.count

        var count = yCount

        if let xBuffer = descriptor.xInputBuffer {
            xValues = xBuffer.toArray()
            xCount = xBuffer.count

            count = Swift.min(xCount, count)
        }
        else {
            xValues = stride(from: 0, to: count, by: 1).map(Double.init)
            xCount = count
        }

        guard count > 0 else {
            mainThread {
                self.clearData()
            }
            return
        }

        let addedCount = count - previousCount

        guard addedCount != 0 else { return }

        if addedCount < 0 {
            guard count <= descriptor.yInputBuffer.memoryCount else {
                print("Attempted to update unbounded function graph with added count > inout buffer memory size. Stopping plotting.")
                return
            }

            mainPointCollection.removeAll()
        }

        lastxCount = xCount
        lastyCount = yCount

        guard addedCount <= descriptor.yInputBuffer.memoryCount else {
            print("Attempted to update unbounded function graph with added count > inout buffer memory size. Stopping plotting.")
            return

        }

        if let xBuffer = descriptor.xInputBuffer {
            guard addedCount <= xBuffer.memoryCount else {
                print("Attempted to update unbounded function graph with added count > inout buffer memory size. Stopping plotting.")
                return
            }
        }

        let xStartIndex = xValues.count - addedCount - (xCount - count)
        let addedXValues = xValues[xStartIndex..<(xStartIndex + addedCount)]

        let yStartIndex = yValues.count - addedCount - (yCount - count)
        let addedYValues = yValues[yStartIndex..<(yStartIndex + addedCount)]

        let zipped = zip(addedXValues, addedYValues)

        let before = mainPointCollection.representedPointCount
        let (replacedPointCount, addedPointCount) = mainPointCollection.append(zipped)
        assert(before + addedCount == mainPointCollection.representedPointCount)

        let logX = descriptor.logX
        let logY = descriptor.logY

        let strideIncreaseFactor = mainPointCollection.count / (maxPoints / 2)

        let replacedAll: Bool

        if strideIncreaseFactor > 1 {
            replacedAll = true

            let before = mainPointCollection.representedPointCount
            mainPointCollection.factorStride(by: strideIncreaseFactor)
            assert(before == mainPointCollection.representedPointCount)

            self.glGraph.drawQuads = true
        }
        else {
            replacedAll = false
        }

        guard active else { return }

        let min = GraphPoint(x: Double(mainPointCollection.minX), y: Double(mainPointCollection.minY))
        let max = GraphPoint(x: Double(mainPointCollection.maxX), y: Double(mainPointCollection.maxY))

        let rangeX = max.x - min.x
        let rangeY = max.y - min.y

     /*   let graphPointsPerPixel = rangeX / Double(graphWidth)

        var resampledPoints: [GraphPoint<GLuint>] = []

        var pointIndex = 0
        for i in 0..<graphWidth {
            var point = currentPoints[pointIndex]

            var entryY: GLuint?
            var exitY: GLuint?

            let resampledLowerX = GLuint((point.xRange.lowerBound - minX) / graphPointsPerPixel)

            // Check if point lower bound samples onto current pixel
            if resampledLowerX == i {
                if entryY == nil {
                    entryY =
                }
                let resampledUpperX = GLuint((point.xRange.upperBound - minX) / graphPointsPerPixel)

            }
        }*/

//        |------8------| points
//        |------4------| graph

//        let graphPointsPerPixel = range / Double(glGraph.frame.width * UIScreen.main.scale)
//
//        let drawnPointsPerPixel = 2 * graphPointsPerPixel / longestStride
//
//        let pointsPerPixel = currentPoints.count / graphWidth
//
//        let pointsToDraw: [RangedGraphPoint<Double>]
//
//        if pointsPerPixel > 1 {
//            print("Start redraw")
//            redraw = true
//            pointsToDraw = currentPoints //mergePoints(currentPoints, by: pointsPerPixel)
//        }
//        else {
//            pointsToDraw = currentPoints
//        }

        let xTicks = ExperimentGraphUtilities.getTicks(min.x, max: max.x, maxTicks: 6, log: logX)
        let yTicks = ExperimentGraphUtilities.getTicks(min.y, max: max.y, maxTicks: 6, log: logY)

        let mappedXTicks = xTicks.map({ (val) -> GraphGridLine in
            return GraphGridLine(absoluteValue: val, relativeValue: CGFloat(((logX ? log(val) : val) - min.x) / rangeX))
        })

        let mappedYTicks = yTicks.map({ (val) -> GraphGridLine in
            return GraphGridLine(absoluteValue: val, relativeValue: CGFloat(((logY ? log(val) : val) - min.y) / rangeY))
        })

        mainThread {
            if self.superview != nil && self.window != nil {
                self.gridView.grid = GraphGrid(xGridLines: mappedXTicks, yGridLines: mappedYTicks)

                if replacedAll {
                    self.glGraph.setPoints(self.mainPointCollection.points, min: min, max: max)
                }
                else {
                    self.glGraph.appendPoints(self.mainPointCollection.points.suffix(addedPointCount + replacedPointCount), replace: replacedPointCount, min: min, max: max)
                }
            }
        }
    }

    var redraw = false

    override func update() {
        let graphWidth = Int(ceil(glGraph.frame.width * UIScreen.main.scale))

        queue.async { [weak self] in
            guard let strongSelf = self, !strongSelf.hasUpdateBlockEnqueued else { return }

            strongSelf.hasUpdateBlockEnqueued = true

            autoreleasepool {
                strongSelf.runUpdate(graphWidth: graphWidth == 0 ? .max : graphWidth)
            }
        }
    }

    func clearData() {
        longestStride = 0.0
        mainPointCollection.removeAll()

        gridView.grid = nil

        glGraph.setPoints([], min: .zero, max: .zero)
    }

    //Mark - General UI

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let s1 = label.sizeThatFits(bounds.size)

        return CGSize(width: size.width, height: Swift.min(size.width/descriptor.aspectRatio + s1.height + 1.0, size.height))
    }

    private var graphFrame: CGRect {
        return gridView.insetRect.offsetBy(dx: gridView.frame.origin.x, dy: gridView.frame.origin.y).integral
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
}

extension ExperimentUnboundedFunctionGraphView: GraphGridDelegate {
    func updatePlotArea() {
        if (glGraph.frame != graphFrame) {
            glGraph.frame = graphFrame
            glGraph.setNeedsLayout()
        }
    }
}
