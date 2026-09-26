//
//  GraphDataManager.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 04.08.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

// MARK: - Graph Data Manager
class GraphDataManager {
    weak var delegate: GraphDataManagerDelegate?
    
    private let descriptor: GraphViewDescriptor
    private let timeReference: ExperimentTimeReference
    //One lock per update instead of one per data point; only touched on the graph queue, by runUpdate and its helpers
    private var timeMappingsSnapshot: [ExperimentTimeReference.TimeMapping] = []
    private let queue = DispatchQueue(label: "de.rwth-aachen.phyphox.graphview", qos: .userInitiated, attributes: [], autoreleaseFrequency: .inherit, target: nil)
    
    private var dataSets: [(bounds: (min: GraphPoint3D<Double>, max: GraphPoint3D<Double>), data2D: [GraphPoint2D<GLfloat>], data3D: [GraphPoint3D<GLfloat>], timeReferenceSets: [TimeReferenceSet])] = []
    
    private var busy = false
    private var lastIndexXArray: [Double]?
    
    private var historicMinX = +Double.infinity
    private var historicMaxX = -Double.infinity
    private var historicMinY = +Double.infinity
    private var historicMaxY = -Double.infinity
    private var historicMinZ = +Double.infinity
    private var historicMaxZ = -Double.infinity
    
    // Zoom state (injected from zoom manager)
    private var zoomMin: GraphPoint3D<Double>?
    private var zoomMax: GraphPoint3D<Double>?
    private var zoomFollows: Bool = false

    //Size of the plot area in points, set by the graph view on layout; only used to measure which out-of-range point
    //is closest to the plot (a distance in view coordinates) and where the arrow towards it points
    var plotSize: CGSize = .zero

    //The range actually shown in the last update: headroom and the opened zero range included
    private var displayedBounds: GraphBounds? = nil
    
    var wantsUpdate = false
    var active = false
    var logX: Bool
    var logY: Bool
    var logZ: Bool
    var systemTime: Bool
    var hasZData: Bool
    
    init(descriptor: GraphViewDescriptor, timeReference: ExperimentTimeReference) {
            self.descriptor = descriptor
            self.timeReference = timeReference
            self.logX = descriptor.logX
            self.logY = descriptor.logY
            self.logZ = descriptor.logZ
            self.systemTime = descriptor.systemTime
            self.hasZData = descriptor.style[0] == .map
        }
    
    func setNeedsUpdate() {
        wantsUpdate = true
    }
    
    func performUpdate() {
        guard !busy, wantsUpdate else { return }
        
        busy = true
        wantsUpdate = false
        
        queue.async { [weak self] in
            autoreleasepool {
                self?.runUpdate()
                self?.busy = false
            }
        }
    }
    
    
    func toggleLogX() {
        logX = !logX
        setNeedsUpdate()
    }
    
    func toggleLogY() {
        logY = !logY
        setNeedsUpdate()
    }
    
    private func runUpdate() {
            timeMappingsSnapshot = timeReference.timeMappings
            var xValues: [[Double]] = []
            var yValues: [[Double]] = []
            var zValues: [[Double]] = []
            var count: [Int] = []
            var points2D: [[GraphPoint2D<GLfloat>]] = []
            var points3D: [[GraphPoint3D<GLfloat>]] = []
            var anyData = false //Any curve delivered a value on any axis

            // Process input buffers
            for i in 0..<descriptor.yInputBuffers.count {
                yValues.insert(descriptor.yInputBuffers[i].toArray(), at: i)
                count.append(yValues[i].count)
                if count[i] > 0 || (descriptor.xInputBuffers[i]?.count ?? 0) > 0 {
                    anyData = true
                }

                if count[i] < 1 {
                    xValues.append([])
                    yValues.append([])
                    zValues.append([])
                    points2D.append([])
                    points3D.append([])
                    continue
                }
                
                // Handle X values
                if let xBuf = descriptor.xInputBuffers[i] {
                    xValues.append(xBuf.toArray())
                } else {
                    var xC = 0
                    if lastIndexXArray != nil {
                        xC = lastIndexXArray!.count
                    }

                    let delta = count[i] - xC
                    if delta > 0 && lastIndexXArray == nil {
                        lastIndexXArray = []
                    }

                    for j in xC..<count[i] {
                        lastIndexXArray!.append(Double(j))
                    }

                    if lastIndexXArray == nil {
                        deliverEmpty(anyData ? .noValidData : .noData)
                        return
                    }
                    xValues.append(lastIndexXArray!)
                }
                
                // Handle Z values
                if let zBuf = descriptor.zInputBuffers[i] {
                    zValues.append(zBuf.toArray())
                } else {
                    zValues.append([])
                }

                count[i] = Swift.min(xValues[i].count, yValues[i].count)
                if descriptor.style[i] == .map {
                    count[i] = Swift.min(count[i], zValues[i].count)
                }

                points2D.append([])
                points3D.append([])
                
                if count[i] < 1 {
                    continue
                }
                
                // Reserve capacity based on style
                let styleCountFactor: Int
                switch descriptor.style[i] {
                case .vbars: styleCountFactor = 6
                case .hbars: styleCountFactor = 6
                default: styleCountFactor = 1
                }
                
                if descriptor.style[i] == .map {
                    points3D[i].reserveCapacity(count[i] * styleCountFactor)
                } else {
                    points2D[i].reserveCapacity(count[i] * styleCountFactor)
                }
            }
            
            if count.reduce(0, Swift.max) < 1 {
                //Values on one axis only (or none at all) leave nothing to draw; the note in the plot says which
                deliverEmpty(anyData ? .noValidData : .noData)
                return
            }

            // Initialize bounds
            var minX = Double.infinity
            var maxX = -Double.infinity
            var minY = Double.infinity
            var maxY = -Double.infinity
            var minZ = Double.infinity
            var maxZ = -Double.infinity

            // Determine strict scaling constraints
            var xMinStrict = (descriptor.scaleMinX == .fixed && !zoomFollows)
            var xMaxStrict = (descriptor.scaleMaxX == .fixed && !zoomFollows)
            var yMinStrict = descriptor.scaleMinY == .fixed
            var yMaxStrict = descriptor.scaleMaxY == .fixed
            var zMinStrict = descriptor.scaleMinZ == .fixed
            var zMaxStrict = descriptor.scaleMaxZ == .fixed

            if xMinStrict { minX = Double(descriptor.minX) }
            if xMaxStrict { maxX = Double(descriptor.maxX) }
            if yMinStrict { minY = Double(descriptor.minY) }
            if yMaxStrict { maxY = Double(descriptor.maxY) }
            if zMinStrict { minZ = Double(descriptor.minZ) }
            if zMaxStrict { maxZ = Double(descriptor.maxZ) }
            
            // Apply zoom constraints
            if let zMin = zoomMin, let zMax = zoomMax {
                if zMin.x.isFinite && zMax.x.isFinite && zMin.x < zMax.x && !zoomFollows {
                    minX = zMin.x
                    maxX = zMax.x
                    xMinStrict = true
                    xMaxStrict = true
                }
                    
                if zMin.y.isFinite && zMax.y.isFinite && zMin.y < zMax.y {
                    minY = zMin.y
                    maxY = zMax.y
                    yMinStrict = true
                    yMaxStrict = true
                }
                
                if zMin.z.isFinite && zMax.z.isFinite && zMin.z < zMax.z {
                    minZ = zMin.z
                    maxZ = zMax.z
                    zMinStrict = true
                    zMaxStrict = true
                }
            }

            // Process data points for each series
            var processedDataSets: [(bounds: (min: GraphPoint3D<Double>, max: GraphPoint3D<Double>), data2D: [GraphPoint2D<GLfloat>], data3D: [GraphPoint3D<GLfloat>], timeReferenceSets: [TimeReferenceSet])] = []
            
            for i in 0..<count.count {
                var xOrderOK = true
                var lastX = -Double.infinity
                var lastY = Double.nan
                
                var timeReferenceSets = [TimeReferenceSet]()
                var lastReferenceIndex = -1
                var lastChange = 0
                
                for j in 0..<count[i] {
                    let rawX = xValues[i][j]
                    let rawY = yValues[i][j]
                    let rawZ = zValues[i].count > j ? zValues[i][j] : Double.nan

                    // Handle time references
                    if descriptor.timeOnX || descriptor.timeOnY {
                        let t = descriptor.timeOnX ? rawX : rawY
                        let referenceIndex = descriptor.linearTime ?
                            timeMappingsSnapshot.referenceIndex(fromLinearTime: t) :
                            timeMappingsSnapshot.referenceIndex(fromExperimentTime: t)
                        
                        if lastReferenceIndex < 0 {
                            lastReferenceIndex = referenceIndex
                        } else if lastReferenceIndex != referenceIndex {
                            timeReferenceSets.append(TimeReferenceSet(
                                index: lastChange,
                                count: j - lastChange,
                                referenceIndex: lastReferenceIndex,
                                experimentTime: timeMappingsSnapshot.experimentTimeReference(byIndex: lastReferenceIndex),
                                systemTime: timeMappingsSnapshot.systemTimeReference(byIndex: lastReferenceIndex),
                                totalPauseGap: timeMappingsSnapshot.totalGap(byIndex: lastReferenceIndex),
                                isPaused: timeMappingsSnapshot.paused(byIndex: lastReferenceIndex)
                            ))
                            lastChange = j
                            lastReferenceIndex = referenceIndex
                        }
                    }
                    
                    // Apply log transformations
                    let x = logX ? log(rawX) : rawX
                    let y = logY ? log(rawY) : rawY
                    let z = logZ ? log(rawZ) : rawZ
                    
                    if x.isFinite && x < lastX {
                        xOrderOK = false
                    }
                    
                    // Update bounds with historic tracking
                    updateBounds(
                        x: x, y: y, z: z,
                        minX: &minX, maxX: &maxX,
                        minY: &minY, maxY: &maxY,
                        minZ: &minZ, maxZ: &maxZ,
                        xMinStrict: xMinStrict, xMaxStrict: xMaxStrict,
                        yMinStrict: yMinStrict, yMaxStrict: yMaxStrict,
                        zMinStrict: zMinStrict, zMaxStrict: zMaxStrict
                    )

                    // Generate points based on graph style
                    generatePoints(
                        for: descriptor.style[i],
                        x: x, y: y, z: z,
                        lastX: lastX, lastY: lastY,
                        lineWidth: Float(descriptor.lineWidth[i]),
                        points2D: &points2D[i],
                        points3D: &points3D[i]
                    )
                    
                    lastX = x
                    lastY = y
                }
                
                // Finalize time reference sets
                if descriptor.timeOnX || descriptor.timeOnY {
                    if lastReferenceIndex < 0 {
                        lastReferenceIndex = 0
                    }
                    timeReferenceSets.append(TimeReferenceSet(
                        index: lastChange,
                        count: count[i] - lastChange,
                        referenceIndex: lastReferenceIndex,
                        experimentTime: timeMappingsSnapshot.experimentTimeReference(byIndex: lastReferenceIndex),
                        systemTime: timeMappingsSnapshot.systemTimeReference(byIndex: lastReferenceIndex),
                        totalPauseGap: timeMappingsSnapshot.totalGap(byIndex: lastReferenceIndex),
                        isPaused: timeMappingsSnapshot.paused(byIndex: lastReferenceIndex)
                    ))
                }

                if !xOrderOK && descriptor.style[i] != .map {
                    print("x values are not ordered!")
                }
                
                processedDataSets.append((
                    bounds: (min: .zero, max: .zero),
                    data2D: points2D[i],
                    data3D: points3D[i],
                    timeReferenceSets: timeReferenceSets
                ))
            }
            
            // Apply zoom follow logic
            if zoomFollows && zoomMin != nil && zoomMax != nil &&
               zoomMin!.x.isFinite && zoomMax!.x.isFinite {
                let w = zoomMax!.x - zoomMin!.x
                zoomMin = GraphPoint3D(x: maxX - w, y: zoomMin!.y, z: zoomMin!.z)
                zoomMax = GraphPoint3D(x: maxX, y: zoomMax!.y, z: zoomMax!.z)
                minX = zoomMin!.x
                maxX = zoomMax!.x
                xMaxStrict = true
                xMinStrict = true
            }
            
            // Apply final adjustments to bounds
            applyFinalBoundsAdjustments(
                minX: &minX, maxX: &maxX,
                minY: &minY, maxY: &maxY,
                xMinStrict: xMinStrict, xMaxStrict: xMaxStrict,
                yMinStrict: yMinStrict, yMaxStrict: yMaxStrict
            )
            
            // Set final bounds for all data sets
            for i in 0..<processedDataSets.count {
                processedDataSets[i].bounds = (
                    min: GraphPoint3D(x: minX, y: minY, z: minZ),
                    max: GraphPoint3D(x: maxX, y: maxY, z: maxZ)
                )
            }

            // Add to data sets with history management
            addDataSets(processedDataSets)

            //All values on an axis identical (or a fixed range with min = max) leaves a zero range and nothing could be
            //drawn. Open it up around the value and mark it with a single tic at that value. This only touches the range
            //of this frame: the data sets (and the extend history) keep their data-derived bounds.
            var finalMin = self.min
            var finalMax = self.max
            var singleTics: (x: GraphGridLine?, y: GraphGridLine?, z: GraphGridLine?) = (nil, nil, nil)
            if finalMin.x.isFinite && finalMin.x == finalMax.x {
                let range = GraphDataManager.openZeroRange(finalMin.x, log: logX)
                singleTics.x = GraphDataManager.singleTic(finalMin.x, log: logX)
                finalMin = GraphPoint3D(x: range.min, y: finalMin.y, z: finalMin.z)
                finalMax = GraphPoint3D(x: range.max, y: finalMax.y, z: finalMax.z)
            }
            if finalMin.y.isFinite && finalMin.y == finalMax.y {
                let range = GraphDataManager.openZeroRange(finalMin.y, log: logY)
                singleTics.y = GraphDataManager.singleTic(finalMin.y, log: logY)
                finalMin = GraphPoint3D(x: finalMin.x, y: range.min, z: finalMin.z)
                finalMax = GraphPoint3D(x: finalMax.x, y: range.max, z: finalMax.z)
            }
            if hasZData && finalMin.z.isFinite && finalMin.z == finalMax.z {
                let range = GraphDataManager.openZeroRange(finalMin.z, log: logZ)
                singleTics.z = GraphDataManager.singleTic(finalMin.z, log: logZ)
                finalMin = GraphPoint3D(x: finalMin.x, y: finalMin.y, z: range.min)
                finalMax = GraphPoint3D(x: finalMax.x, y: finalMax.y, z: range.max)
            }
            let finalBounds = GraphBounds(min: finalMin, max: finalMax)
            displayedBounds = finalBounds

            // Generate grid and pause markers
            let grid = generateGrid(min: finalMin, max: finalMax, singleTics: singleTics)
            let pauseMarkers = descriptor.hideTimeMarkers ? nil : generatePauseMarkers(min: finalMin, max: finalMax)

            let status = classifyData(xValues: xValues, yValues: yValues, count: count, bounds: finalBounds)

            // Prepare final data for main thread
            let result = GraphDataResult(
                dataSets: currentGraphDataSets,
                bounds: finalBounds,
                grid: grid,
                dataStatus: status.status,
                arrowAngle: status.arrowAngle
            )

            // Update UI on main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.dataManager(self, didUpdateData: result, pauseMarkers: pauseMarkers)
            }
        }

        private func deliverEmpty(_ status: GraphDataStatus) {
            displayedBounds = nil
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.dataManagerDidClearData(status: status)
            }
        }

        //Symmetric range around a single value v: 5 % of its magnitude, one unit if v is zero, a factor of 1.05 on a
        //log axis (v is log(value) there, so the factor becomes an offset)
        static func openZeroRange(_ v: Double, log isLog: Bool) -> (min: Double, max: Double) {
            if isLog {
                return (v - log(1.05), v + log(1.05))
            }
            let half = v == 0 ? 1.0 : abs(v) * 0.05
            return (v - half, v + half)
        }

        //The tic marking a single value, centered in the opened range, with as many decimals as needed to show it exactly (at most four)
        static func singleTic(_ v: Double, log isLog: Bool) -> GraphGridLine {
            var value = isLog ? exp(v) : v
            var precision = 4
            for p in 0..<4 {
                let scaled = value * pow(10.0, Double(p))
                if abs(scaled - scaled.rounded()) < 1e-6 {
                    precision = p
                    value = scaled.rounded() / pow(10.0, Double(p)) //exp(log(100)) is not quite 100
                    break
                }
            }
            return GraphGridLine(absoluteValue: value, relativeValue: 0.5, precision: precision)
        }

        //Classify the current buffers against the range that is shown, so an empty plot can say why it is empty. Scans
        //newest points first and stops at the first visible one, so a graph that shows data pays almost nothing.
        //A time axis compares the point at the displayed time, like the plot and the marker do.
        private func classifyData(xValues: [[Double]], yValues: [[Double]], count: [Int], bounds: GraphBounds) -> (status: GraphDataStatus, arrowAngle: Double?) {
            var anyData = false
            var anyValid = false
            //The plot in view coordinates: width w, height h, origin top left. Without a layout yet, a unit square.
            let w = plotSize.width > 0 ? Double(plotSize.width) : 1.0
            let h = plotSize.height > 0 ? Double(plotSize.height) : 1.0
            let xRange = bounds.max.x - bounds.min.x
            let yRange = bounds.max.y - bounds.min.y
            var nearestD = Double.infinity
            var nearest: (x: Double, y: Double)? = nil

            for i in stride(from: count.count - 1, through: 0, by: -1) {
                if xValues[i].count > 0 || yValues[i].count > 0 {
                    anyData = true
                }
                for j in stride(from: count[i] - 1, through: 0, by: -1) {
                    let rawX = xValues[i][j]
                    let rawY = yValues[i][j]
                    if !rawX.isFinite || !rawY.isFinite {
                        continue
                    }
                    anyValid = true
                    var x = logX ? log(rawX) : rawX
                    var y = logY ? log(rawY) : rawY
                    if descriptor.timeOnX {
                        x += timeOffset(experimentTime: x)
                    }
                    if descriptor.timeOnY {
                        y += timeOffset(experimentTime: y)
                    }
                    //Non-positive values on a log axis are not invalid, they lie beyond the negative end of the axis
                    let belowLogX = logX && rawX <= 0
                    let belowLogY = logY && rawY <= 0
                    if !belowLogX && !belowLogY && x >= bounds.min.x && x <= bounds.max.x && y >= bounds.min.y && y <= bounds.max.y {
                        return (.ok, nil)
                    }
                    //Not visible. Remember it if it is the one closest to the plot area, so an arrow can point there.
                    let vx = belowLogX ? -1e6 : (x - bounds.min.x) / xRange * w
                    let vy = belowLogY ? h + 1e6 : (bounds.max.y - y) / yRange * h
                    if !vx.isFinite || !vy.isFinite {
                        continue
                    }
                    let dx = vx < 0 ? -vx : Swift.max(vx - w, 0)
                    let dy = vy < 0 ? -vy : Swift.max(vy - h, 0)
                    let d = dx * dx + dy * dy
                    if d < nearestD {
                        nearestD = d
                        nearest = (vx, vy)
                    }
                }
            }

            if !anyData {
                return (.noData, nil)
            } else if !anyValid {
                return (.noValidData, nil)
            } else if let nearest = nearest {
                //Screen angle from the plot centre towards the nearest point (view y grows downwards)
                return (.noDataInRange, atan2(nearest.y - h / 2.0, nearest.x - w / 2.0))
            } else {
                return (.noDataInRange, nil)
            }
        }

        //Experiment time to displayed time on a time axis, as the plot's shader and the marker apply it
        private func timeOffset(experimentTime t: Double) -> Double {
            if systemTime && !descriptor.linearTime {
                return timeMappingsSnapshot.totalGap(byIndex: timeMappingsSnapshot.referenceIndex(fromExperimentTime: t))
            } else if !systemTime && descriptor.linearTime {
                return -timeMappingsSnapshot.totalGap(byIndex: timeMappingsSnapshot.referenceIndex(fromLinearTime: t))
            }
            return 0.0
        }
    
    private func updateBounds(
            x: Double, y: Double, z: Double,
            minX: inout Double, maxX: inout Double,
            minY: inout Double, maxY: inout Double,
            minZ: inout Double, maxZ: inout Double,
            xMinStrict: Bool, xMaxStrict: Bool,
            yMinStrict: Bool, yMaxStrict: Bool,
            zMinStrict: Bool, zMaxStrict: Bool
        ) {
            if x.isFinite && x < minX && !xMinStrict {
                minX = x
                if minX < historicMinX {
                    historicMinX = minX
                } else if descriptor.scaleMinX == .extend {
                    minX = historicMinX
                }
            }

            if x.isFinite && x > maxX && !xMaxStrict {
                maxX = x
                if maxX > historicMaxX {
                    historicMaxX = maxX
                } else if descriptor.scaleMaxX == .extend {
                    maxX = historicMaxX
                }
            }

            if y.isFinite && y < minY && !yMinStrict {
                minY = y
                if minY < historicMinY {
                    historicMinY = minY
                } else if descriptor.scaleMinY == .extend {
                    minY = historicMinY
                }
            }

            if y.isFinite && y > maxY && !yMaxStrict {
                maxY = y
                if maxY > historicMaxY {
                    historicMaxY = maxY
                } else if descriptor.scaleMaxY == .extend {
                    maxY = historicMaxY
                }
            }
            
            if z.isFinite && z < minZ && !zMinStrict {
                minZ = z
                if minZ < historicMinZ {
                    historicMinZ = minZ
                } else if descriptor.scaleMinZ == .extend {
                    minZ = historicMinZ
                }
            }
            
            if z.isFinite && z > maxZ && !zMaxStrict {
                maxZ = z
                if maxZ > historicMaxZ {
                    historicMaxZ = maxZ
                } else if descriptor.scaleMaxZ == .extend {
                    maxZ = historicMaxZ
                }
            }
        }
        
        private func generatePoints(
            for style: GraphViewDescriptor.GraphStyle,
            x: Double, y: Double, z: Double,
            lastX: Double, lastY: Double,
            lineWidth: Float,
            points2D: inout [GraphPoint2D<GLfloat>],
            points3D: inout [GraphPoint3D<GLfloat>]
        ) {
            switch style {
            case .hbars:
                if lastX.isFinite && lastY.isFinite {
                    let off = (y - lastY) * (1.0 - Double(lineWidth)) / 2.0
                    let yOff = y - off
                    let lastYOff = lastY + off
                    points2D.append(GraphPoint2D(x: GLfloat(0.0), y: GLfloat(lastYOff)))
                    points2D.append(GraphPoint2D(x: GLfloat(0.0), y: GLfloat(yOff)))
                    points2D.append(GraphPoint2D(x: GLfloat(lastX), y: GLfloat(lastYOff)))
                    points2D.append(GraphPoint2D(x: GLfloat(lastX), y: GLfloat(yOff)))
                    points2D.append(GraphPoint2D(x: GLfloat(lastX), y: GLfloat(lastYOff)))
                    points2D.append(GraphPoint2D(x: GLfloat(0.0), y: GLfloat(yOff)))
                }
            case .vbars:
                if lastX.isFinite && lastY.isFinite {
                    let off = (x - lastX) * (1.0 - Double(lineWidth)) / 2.0
                    let xOff = x - off
                    let lastXOff = lastX + off
                    points2D.append(GraphPoint2D(x: GLfloat(lastXOff), y: GLfloat(0.0)))
                    points2D.append(GraphPoint2D(x: GLfloat(xOff), y: GLfloat(0.0)))
                    points2D.append(GraphPoint2D(x: GLfloat(lastXOff), y: GLfloat(lastY)))
                    points2D.append(GraphPoint2D(x: GLfloat(xOff), y: GLfloat(lastY)))
                    points2D.append(GraphPoint2D(x: GLfloat(lastXOff), y: GLfloat(lastY)))
                    points2D.append(GraphPoint2D(x: GLfloat(xOff), y: GLfloat(0.0)))
                }
            case .map:
                points3D.append(GraphPoint3D(x: GLfloat(x), y: GLfloat(y), z: GLfloat(z)))
            default:
                if !(x.isFinite && y.isFinite) {
                    points2D.append(GraphPoint2D(x: GLfloat.nan, y: GLfloat.nan))
                } else {
                    points2D.append(GraphPoint2D(x: GLfloat(x), y: GLfloat(y)))
                }
            }
        }
        
        private func applyFinalBoundsAdjustments(
            minX: inout Double, maxX: inout Double,
            minY: inout Double, maxY: inout Double,
            xMinStrict: Bool, xMaxStrict: Bool,
            yMinStrict: Bool, yMaxStrict: Bool
        ) {
            if systemTime && !descriptor.linearTime && descriptor.timeOnX && !xMinStrict && !xMaxStrict && !hasZData {
                minX += timeMappingsSnapshot.totalGap(byIndex: timeMappingsSnapshot.referenceIndex(fromExperimentTime: minX))
                maxX += timeMappingsSnapshot.totalGap(byIndex: timeMappingsSnapshot.referenceIndex(fromExperimentTime: maxX))
            } else if !systemTime && descriptor.linearTime && descriptor.timeOnX && !xMinStrict && !xMaxStrict && !hasZData {
                minX -= timeMappingsSnapshot.totalGap(byIndex: timeMappingsSnapshot.referenceIndex(fromLinearTime: minX))
                maxX -= timeMappingsSnapshot.totalGap(byIndex: timeMappingsSnapshot.referenceIndex(fromLinearTime: maxX))
            } else if !logX && !hasZData && !descriptor.timeOnX {
                //Stretch slightly to give a little headroom, but only at ends the data determines: a fixed or zoomed
                //end is shown exactly (decided 2026-09-20)
                let extraX = (maxX - minX) * 0.05
                if !xMaxStrict { maxX += extraX }
                if !xMinStrict { minX -= extraX }
            }
            
            if systemTime && !descriptor.linearTime && descriptor.timeOnY && !yMinStrict && !yMaxStrict && !hasZData {
                minY += timeMappingsSnapshot.totalGap(byIndex: timeMappingsSnapshot.referenceIndex(fromExperimentTime: minY))
                maxY += timeMappingsSnapshot.totalGap(byIndex: timeMappingsSnapshot.referenceIndex(fromExperimentTime: maxY))
            } else if !systemTime && descriptor.linearTime && descriptor.timeOnY && !yMinStrict && !yMaxStrict && !hasZData {
                minY -= timeMappingsSnapshot.totalGap(byIndex: timeMappingsSnapshot.referenceIndex(fromExperimentTime: minY))
                maxY -= timeMappingsSnapshot.totalGap(byIndex: timeMappingsSnapshot.referenceIndex(fromExperimentTime: maxY))
            } else if !logY && !hasZData && !descriptor.timeOnY {
                let extraY = (maxY - minY) * 0.05
                if !yMaxStrict { maxY += extraY }
                if !yMinStrict { minY -= extraY }
            }
            
            if descriptor.timeOnX && !descriptor.linearTime && !xMinStrict && !xMaxStrict && !hasZData {
                minX = Swift.min(minX, timeMappingsSnapshot.experimentTimeReference(byIndex: 0))
            }
        }
        
        private func addDataSets(_ sets: [(bounds: (min: GraphPoint3D<Double>, max: GraphPoint3D<Double>), data2D: [GraphPoint2D<GLfloat>], data3D: [GraphPoint3D<GLfloat>], timeReferenceSets: [TimeReferenceSet])]) {
            if descriptor.history > 1 {
                if dataSets.count >= Int(descriptor.history) {
                    dataSets.removeFirst()
                }
                dataSets.append(sets[0])
            } else {
                dataSets = sets
            }
        }
        
        private func generateGrid(min minValue: GraphPoint3D<Double>, max maxValue: GraphPoint3D<Double>, singleTics: (x: GraphGridLine?, y: GraphGridLine?, z: GraphGridLine?)) -> GraphGrid {
            let minX = minValue.x
            let maxX = maxValue.x
            let minY = minValue.y
            let maxY = maxValue.y
            let minZ = minValue.z
            let maxZ = maxValue.z
            let xRange = maxX - minX
            let yRange = maxY - minY
            let zRange = maxZ - minZ

            let xTicks = ExperimentGraphUtilities.getTicks(
                minX, max: maxX,
                maxTicks: descriptor.timeOnX && systemTime ? 4 : 5,
                log: logX,
                isTime: descriptor.timeOnX,
                systemTimeOffset: systemTimeOffset(timeOnAxis: descriptor.timeOnX)
            )
            let yTicks = ExperimentGraphUtilities.getTicks(
                minY, max: maxY,
                maxTicks: 5,
                log: logY,
                isTime: descriptor.timeOnY,
                systemTimeOffset: systemTimeOffset(timeOnAxis: descriptor.timeOnY)
            )
            let zTicks = ExperimentGraphUtilities.getTicks(
                minZ, max: maxZ,
                maxTicks: 5,
                log: logZ,
                isTime: false,
                systemTimeOffset: 0.0
            )

            let mappedXTicks = singleTics.x.map { [$0] } ?? xTicks.map { tick in
                GraphGridLine(
                    absoluteValue: tick.value,
                    relativeValue: CGFloat(((logX ? log(tick.value) : tick.value) - minX) / xRange),
                    precision: tick.precision
                )
            }

            let mappedYTicks = singleTics.y.map { [$0] } ?? yTicks.map { tick in
                GraphGridLine(
                    absoluteValue: tick.value,
                    relativeValue: CGFloat(((logY ? log(tick.value) : tick.value) - minY) / yRange),
                    precision: tick.precision
                )
            }
            
            let mappedZTicks = singleTics.z.map { [$0] } ?? zTicks.map { tick in
                GraphGridLine(
                    absoluteValue: tick.value,
                    relativeValue: CGFloat(((logZ ? log(tick.value) : tick.value) - minZ) / zRange),
                    precision: tick.precision
                )
            }

           
            return GraphGrid(
                xGridLines: mappedXTicks,
                yGridLines: mappedYTicks,
                zGridLines: mappedZTicks,
                systemTimeOffsetX: systemTimeOffset(timeOnAxis: descriptor.timeOnX),
                systemTimeOffsetY: systemTimeOffset(timeOnAxis: descriptor.timeOnY)
            )
        }
        
        private func generatePauseMarkers(min minValue: GraphPoint3D<Double>, max maxValue: GraphPoint3D<Double>) -> PauseRanges {
            let minX = minValue.x
            let maxX = maxValue.x
            let minY = minValue.y
            let maxY = maxValue.y
            let xRange = maxX - minX
            let yRange = maxY - minY
            
            if descriptor.timeOnX {
                if xRange == 0 {
                    return PauseRanges(xPauseRanges: [], yPauseRanges: [])
                }
                var pauseRanges: [PauseRange] = []
                var rangeStart: CGFloat? = nil

                let mappings = timeMappingsSnapshot
                for i in 0..<mappings.count {
                    let t = timeMappingsSnapshot.experimentTimeReference(byIndex: i) +
                           (systemTime ? timeMappingsSnapshot.totalGap(byIndex: i) : 0.0)
                    let relativeT = CGFloat((t - minX) / xRange)

                    if t < minX || t > maxX {
                        continue
                    }

                    if mappings[i].event == .PAUSE {
                        rangeStart = relativeT
                    } else {
                        pauseRanges.append(PauseRange(relativeBegin: rangeStart ?? 0.0, relativeEnd: relativeT))
                        rangeStart = nil
                    }
                }
                
                if let openEnded = rangeStart {
                    pauseRanges.append(PauseRange(relativeBegin: openEnded, relativeEnd: 1.0))
                }
                
                return PauseRanges(xPauseRanges: pauseRanges, yPauseRanges: [])
                
            } else if descriptor.timeOnY {
                if yRange == 0 {
                    return PauseRanges(xPauseRanges: [], yPauseRanges: [])
                }
                var pauseRanges: [PauseRange] = []
                var rangeStart: CGFloat? = nil

                let mappings = timeMappingsSnapshot
                for i in 0..<mappings.count {
                    let t = timeMappingsSnapshot.experimentTimeReference(byIndex: i) +
                           (systemTime ? timeMappingsSnapshot.totalGap(byIndex: i) : 0.0)
                    let relativeT = CGFloat((t - minY) / yRange)

                    if t < minY || t > maxY {
                        continue
                    }

                    if mappings[i].event == .START {
                        rangeStart = relativeT
                    } else {
                        pauseRanges.append(PauseRange(relativeBegin: rangeStart ?? 0.0, relativeEnd: relativeT))
                        rangeStart = nil
                    }
                }
                
                if let openEnded = rangeStart {
                    pauseRanges.append(PauseRange(relativeBegin: openEnded, relativeEnd: 1.0))
                }
                
                return PauseRanges(xPauseRanges: [], yPauseRanges: pauseRanges)
            } else {
                return PauseRanges(xPauseRanges: [], yPauseRanges: [])
            }
        }
        
        private func systemTimeOffset(timeOnAxis: Bool) -> Double {
            if let first = timeMappingsSnapshot.first, systemTime && timeOnAxis {
                return first.systemTime.timeIntervalSince1970 - first.experimentTime
            }
            return 0.0
        }
        
        // MARK: - Public Interface
        
        func clearData() {
            dataSets.removeAll()
            lastIndexXArray = nil
            historicMinX = +Double.infinity
            historicMaxX = -Double.infinity
            historicMinY = +Double.infinity
            historicMaxY = -Double.infinity
            historicMinZ = +Double.infinity
            historicMaxZ = -Double.infinity
            displayedBounds = nil
            
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.dataManagerDidClearData(status: .noData)
            }
        }
    
    func updateZoomState(min: GraphPoint3D<Double>?, max: GraphPoint3D<Double>?, follows: Bool) {
            zoomMin = min
            zoomMax = max
            zoomFollows = follows
        }
    
    var currentDataSets: [GraphDataSet] {
           return currentGraphDataSets
       }
    
    private var currentGraphDataSets: [GraphDataSet] {
            return dataSets.map { dataSet in
                GraphDataSet(
                    points2D: dataSet.data2D,
                    points3D: dataSet.data3D,
                    bounds: GraphBounds(min: dataSet.bounds.min, max: dataSet.bounds.max),
                    timeReferenceSets: dataSet.timeReferenceSets
                )
            }
        }
    
    //The range on screen, which gestures and the marker work in
    var currentBounds: GraphBounds {
        return displayedBounds ?? GraphBounds(min: min, max: max)
    }
    
    var points2D: [[GraphPoint2D<GLfloat>]] {
            return dataSets.map { $0.data2D }
        }
        
        var points3D: [[GraphPoint3D<GLfloat>]] {
            return dataSets.map { $0.data3D }
        }
        
        var timeReferenceSets: [[TimeReferenceSet]] {
            return dataSets.map { $0.timeReferenceSets }
        }
    
    private var max: GraphPoint3D<Double> {
        guard !dataSets.isEmpty else { return GraphPoint3D.zero }
        
        var maxX = -Double.infinity
        var maxY = -Double.infinity
        var maxZ = -Double.infinity
        
        for set in dataSets {
            let maxPoint = set.bounds.max
            maxX = Swift.max(maxX, maxPoint.x)
            maxY = Swift.max(maxY, maxPoint.y)
            maxZ = Swift.max(maxZ, maxPoint.z)
        }
        
        
        return GraphPoint3D(x: maxX, y: maxY, z: maxZ)
    }
    
    private var min: GraphPoint3D<Double> {
        guard !dataSets.isEmpty else { return GraphPoint3D.zero }
        
        var minX = Double.infinity
        var minY = Double.infinity
        var minZ = Double.infinity
        
        for set in dataSets {
            let minPoint = set.bounds.min
            minX = Swift.min(minX, minPoint.x)
            minY = Swift.min(minY, minPoint.y)
            minZ = Swift.min(minZ, minPoint.z)
        }
        
        return GraphPoint3D(x: minX, y: minY, z: minZ)
    }
}

protocol GraphDataManagerDelegate: AnyObject {
    func dataManager(_ manager: GraphDataManager, didUpdateData data: GraphDataResult, pauseMarkers: PauseRanges?)
    func dataManagerDidClearData(status: GraphDataStatus)
}

//Why the plot area is empty, shown as a small note instead of leaving it blank
enum GraphDataStatus {
    case ok, noData, noValidData, noDataInRange
}

struct GraphDataResult {
    let dataSets: [GraphDataSet]
    let bounds: GraphBounds
    let grid: GraphGrid
    let dataStatus: GraphDataStatus
    let arrowAngle: Double? //Screen angle in radians from the plot centre towards the nearest valid point, for noDataInRange
}

struct GraphDataSet {
    let points2D: [GraphPoint2D<GLfloat>]
    let points3D: [GraphPoint3D<GLfloat>]
    let bounds: GraphBounds
    let timeReferenceSets: [TimeReferenceSet]
}

struct GraphBounds {
    let min: GraphPoint3D<Double>
    let max: GraphPoint3D<Double>
}

extension ExperimentGraphView: GraphDataManagerDelegate {
    func dataManager(_ manager: GraphDataManager, didUpdateData data: GraphDataResult, pauseMarkers: PauseRanges?) {
        
        // Update grid with pause markers
        graphRenderer.gridView.grid = data.grid
        graphRenderer.gridView.pauseMarkers = pauseMarkers
        graphRenderer.zGridView?.grid = data.grid
        
        markerSystem.updateDataContext(dataSets: data.dataSets, bounds: data.bounds, systemTime: systemTime)
        
        // Update renderer with new data
        graphRenderer.updateData(data)

        //Plot frame not updated here: a changed axis label space is reported by the grid's layout pass via updatePlotArea

        // Update GL graph view
        graphRenderer.plotView.setPoints(
            points2D: data.dataSets.map { $0.points2D },
            points3D: data.dataSets.map { $0.points3D },
            min: data.bounds.min,
            max: data.bounds.max,
            timeReferenceSets: data.dataSets.map { $0.timeReferenceSets }
        )
        
        markerSystem.refreshMarkers()

        syncPickDataFromBuffers()

        graphRenderer.plotView.accessibilityValue = axisRangesDescription(data.bounds)
        graphRenderer.statusView.show(data.dataStatus, arrowAngle: data.arrowAngle)
    }

    //"x from -0.4 to 8.4, y from 0.2 to 17.8" in the axes' own units (log axes converted back)
    private func axisRangesDescription(_ bounds: GraphBounds) -> String {
        let x = (dataManager.logX ? exp(bounds.min.x) : bounds.min.x, dataManager.logX ? exp(bounds.max.x) : bounds.max.x)
        let y = (dataManager.logY ? exp(bounds.min.y) : bounds.min.y, dataManager.logY ? exp(bounds.max.y) : bounds.max.y)
        return String(format: "x from %g to %g, y from %g to %g", x.0, x.1, y.0, y.1)
    }



    func dataManagerDidClearData(status: GraphDataStatus) {
        graphRenderer.clearGraph()
        graphRenderer.statusView.show(status, arrowAngle: nil)
        markerSystem.clearMarkers()
        graphRenderer.plotView.accessibilityValue = nil

        syncPickDataFromBuffers()
    }
}

