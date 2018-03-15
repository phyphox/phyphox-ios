//
//  PointCollection.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.03.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

struct RangedGraphPoint<T: Comparable & Numeric> {
    let xRange: ClosedRange<T>
    let yRange: ClosedRange<T>
}

struct PointCollection {
    private let logX: Bool
    private let logY: Bool

    private(set) var points: [RangedGraphPoint<GLfloat>] = []

    private var currentStride = 1
    private var currentOffsetFromLastPoint = 0

    private(set) var maxX = -GLfloat.infinity
    private(set) var minX = GLfloat.infinity

    private(set) var maxY = -GLfloat.infinity
    private(set) var minY = GLfloat.infinity

    private(set) var longestStride: GLfloat = 0.0

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

    init(logX: Bool, logY: Bool) {
        self.logX = logX
        self.logY = logY
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

    mutating func append<S: Sequence>(_ newPoints: S) -> (replacedPointCount: Int, appendedPointCount: Int) where S.Element == (Double, Double) {
        func commitPoint(_ point: RangedGraphPoint<GLfloat>) {
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
