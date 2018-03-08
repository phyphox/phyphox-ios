//
//  ExperimentUnboundedFunctionGraphView.swift
//  phyphox
//
//  Created by Jonas Gessner on 07.03.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import UIKit

protocol GraphViewModuleProtocol {
    var queue: DispatchQueue? { get set }

    func clearData()
    func animateFrame(_ frame: CGRect)
}

typealias GraphViewModule = ExperimentViewModule<GraphViewDescriptor> & GraphViewModuleProtocol

struct RangedGraphPoint<T: Comparable & Numeric> {
    let xRange: ClosedRange<T>
    let yRange: ClosedRange<T>
}

private let maxPoints = 5000

/**
 Graph view used to display functions (where each x value is is related to exactly one y value) where the stream of incoming x values is in ascending order (descriptor.partialUpdate = true on the view descriptor) and all values are retained (inputBuffer sizes are 0). The displayed history also has to be 1 (descriptor.history = 1).
 */
final class ExperimentUnboundedFunctionGraphView: ExperimentViewModule<GraphViewDescriptor>, GraphViewModuleProtocol {
    var queue: DispatchQueue?

    private let xLabel: UILabel
    private let yLabel: UILabel

    private let glGraph: GLRangedPointGraphView
    private let gridView: GraphGridView

    private var maxX: Double
    private var minX: Double
    private var maxY: Double
    private var minY: Double

    required init?(descriptor: GraphViewDescriptor) {
        guard descriptor.partialUpdate && descriptor.history == 1 && descriptor.yInputBuffer.size == 0 && (descriptor.xInputBuffer?.size ?? 0) == 0 else { return nil }

        maxX = -Double.infinity
        minX = Double.infinity

        maxY = -Double.infinity
        minY = Double.infinity

        glGraph = GLRangedPointGraphView()
        glGraph.drawDots = descriptor.drawDots
        glGraph.lineWidth = Float(descriptor.lineWidth * (descriptor.drawDots ? 4.0 : 2.0))
        var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0

        descriptor.color.getRed(&r, green: &g, blue: &b, alpha: &a)
        glGraph.lineColor = GLcolor(r: Float(r), g: Float(g), b: Float(b), a: Float(a))
       // glGraph.historyLength = 1

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

    private var currentPoints: [RangedGraphPoint<Double>] = []
    private var currentStride = 1
    private var currentOffsetFromLastPoint = 0

    private var hasUpdateBlockEnqueued = false

    private func merge<C: Collection, T>(point: RangedGraphPoint<T>, with points: C) -> RangedGraphPoint<T> where C.Element == RangedGraphPoint<T> {
        var minX = point.xRange.lowerBound
        var maxX = point.xRange.upperBound

        var minY = point.yRange.lowerBound
        var maxY = point.yRange.upperBound

        points.forEach {
            minX = Swift.min(minX, $0.xRange.lowerBound)
            maxX = Swift.max(maxX, $0.xRange.upperBound)

            minY = Swift.min(minY, $0.yRange.lowerBound)
            maxY = Swift.max(maxY, $0.yRange.upperBound)
        }

        return RangedGraphPoint(xRange: minX...maxX, yRange: minY...maxY)
    }

    private func increaseStride(by factor: Int) {
        print("Increase stride by \(factor)")

        var mergedPoints = [RangedGraphPoint<Double>]()
        // Merge each group of `factor` points. If the number of points is not divisible by `factor` a number of "dangling" points remain that together form a new incomplete point
        let danglingPointCount = (currentPoints.count % factor)

        mergedPoints.reserveCapacity(currentPoints.count/factor + danglingPointCount)

        for i in stride(from: 0, to: currentPoints.count - danglingPointCount, by: factor) {
            let currentPoint = currentPoints[i]

            let nextPoints = currentPoints[i + 1..<i + factor]

            let mergedPoint = merge(point: currentPoint, with: nextPoints)

            mergedPoints.append(mergedPoint)
        }

        // If there is no dangling point and the last point was not complete we have to increase the offset by the current stride times the number of points that were merged with the incomplete last point (factor - 1). The point created by merging the last `factor` points will also not be complete since the previous last point was incomplete.
        if danglingPointCount == 0 && currentOffsetFromLastPoint > 0 {
            currentOffsetFromLastPoint += (factor - 1) * currentStride
        }

        let danglingPoints = Array(currentPoints.suffix(danglingPointCount))

        // If there are dangling points, we merge the dangling points
        if !danglingPoints.isEmpty {
            let firstDanglingPoint = danglingPoints[0]

            let merged = merge(point: firstDanglingPoint, with: danglingPoints[1...])

            mergedPoints.append(merged)

            // If the last point was complete the new offset is `number of dangling points * current stride`. If the last point was incomplete the new offset is `oldOffset + currentStride * (number of dangling points - 1)`
            if currentOffsetFromLastPoint == 0 {
                currentOffsetFromLastPoint = currentStride * danglingPoints.count
            }
            else {
                currentOffsetFromLastPoint += currentStride * (danglingPoints.count - 1)
            }
        }

        currentPoints = mergedPoints
        currentStride *= factor
    }

    private func runUpdate() {
        defer {
            hasUpdateBlockEnqueued = false
        }

        let previousCount = currentPoints.count * currentStride + currentOffsetFromLastPoint

        var xValues: [Double]
        let yValues = descriptor.yInputBuffer.toArray()

        var xCount: Int
        let yCount = descriptor.yInputBuffer.count

        var count = yCount

        if let xBuf = descriptor.xInputBuffer {
            xValues = xBuf.toArray()
            xCount = xBuf.count

            count = Swift.min(xCount, count)
        }
        else {
            xValues = stride(from: 0, to: count, by: 1).map(Double.init)
            xCount = count
        }

        let addedCount = count - previousCount

        guard addedCount > 0 else { return }
        guard addedCount <= maxPoints else { return }

        let xStartIndex = xValues.count - addedCount - (xCount - count)
        let addedXValues = xValues[xStartIndex..<(xStartIndex + addedCount)]

        let yStartIndex = yValues.count - addedCount - (yCount - count)
        let addedYValues = yValues[yStartIndex..<(yStartIndex + addedCount)]

        var currentPoint = currentPoints.popLast()

        func commitPoint(_ point: RangedGraphPoint<Double>) {
            currentPoints.append(point)
            maxX = Swift.max(point.xRange.upperBound, maxX)
            minX = Swift.min(point.xRange.lowerBound, minX)

            maxY = Swift.max(point.yRange.upperBound, maxY)
            minY = Swift.min(point.yRange.lowerBound, minY)

            currentOffsetFromLastPoint = 0
        }

        for (x, y) in zip(addedXValues, addedYValues) {
            if currentOffsetFromLastPoint == 0 {
                currentPoint = RangedGraphPoint(xRange: x...x, yRange: y...y)

                currentOffsetFromLastPoint = 1

                if currentOffsetFromLastPoint == currentStride, let point = currentPoint {
                    commitPoint(point)
                    currentOffsetFromLastPoint = 0
                }
            }
            else if let point = currentPoint {
                let xRange = point.xRange.lowerBound...x
                let yRange = Swift.min(point.yRange.lowerBound, y)...Swift.max(point.yRange.upperBound, y)

                currentPoint = RangedGraphPoint(xRange: xRange, yRange: yRange)

                currentOffsetFromLastPoint += 1

                if currentOffsetFromLastPoint == currentStride, let point = currentPoint {
                    commitPoint(point)
                    currentOffsetFromLastPoint = 0
                }
            }
        }

        let strideIncreaseFactor = currentPoints.count / maxPoints

        if strideIncreaseFactor > 1 {
            increaseStride(by: strideIncreaseFactor)
        }

        let min = GraphPoint(x: minX, y: minY)
        let max = GraphPoint(x: maxX, y: maxY)

        mainThread {
            if self.superview != nil && self.window != nil {
                //self.gridView.grid = GraphGrid(xGridLines: mappedXTicks, yGridLines: mappedYTicks)
                self.glGraph.setPoints(self.currentPoints, min: min, max: max)
            }
        }
    }

    // TODO: Always update
    override func update() {
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
        currentStride = 1
        currentOffsetFromLastPoint = 0
        currentPoints = []
        clearGraph()
    }

    private func clearGraph() {
        maxX = -Double.infinity
        minX = Double.infinity

        maxY = -Double.infinity
        minY = Double.infinity

        gridView.grid = nil

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

extension ExperimentUnboundedFunctionGraphView: GraphGridDelegate {
    func updatePlotArea() {
        if (glGraph.frame != graphFrame) {
            glGraph.frame = graphFrame
            glGraph.setNeedsLayout()
        }
    }
}

