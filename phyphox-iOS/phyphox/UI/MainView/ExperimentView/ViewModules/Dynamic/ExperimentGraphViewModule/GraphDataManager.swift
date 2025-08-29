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
            var xValues: [[Double]] = []
            var yValues: [[Double]] = []
            var zValues: [[Double]] = []
            var count: [Int] = []
            var points2D: [[GraphPoint2D<GLfloat>]] = []
            var points3D: [[GraphPoint3D<GLfloat>]] = []

            // Process input buffers
            for i in 0..<descriptor.yInputBuffers.count {
                yValues.insert(descriptor.yInputBuffers[i].toArray(), at: i)
                count.append(yValues[i].count)

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
                        DispatchQueue.main.async { [weak self] in
                            self?.delegate?.dataManagerDidClearData()
                        }
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
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.dataManagerDidClearData()
                }
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
                            timeReference.getReferenceIndexFromLinearTime(t: t) :
                            timeReference.getReferenceIndexFromExperimentTime(t: t)
                        
                        if lastReferenceIndex < 0 {
                            lastReferenceIndex = referenceIndex
                        } else if lastReferenceIndex != referenceIndex {
                            timeReferenceSets.append(TimeReferenceSet(
                                index: lastChange,
                                count: j - lastChange,
                                referenceIndex: lastReferenceIndex,
                                experimentTime: timeReference.getExperimentTimeReferenceByIndex(i: lastReferenceIndex),
                                systemTime: timeReference.getSystemTimeReferenceByIndex(i: lastReferenceIndex),
                                totalPauseGap: timeReference.getTotalGapByIndex(i: lastReferenceIndex),
                                isPaused: timeReference.getPausedByIndex(i: lastReferenceIndex)
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
                        experimentTime: timeReference.getExperimentTimeReferenceByIndex(i: lastReferenceIndex),
                        systemTime: timeReference.getSystemTimeReferenceByIndex(i: lastReferenceIndex),
                        totalPauseGap: timeReference.getTotalGapByIndex(i: lastReferenceIndex),
                        isPaused: timeReference.getPausedByIndex(i: lastReferenceIndex)
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

            // Generate grid and pause markers
            let grid = generateGrid(logX: logX, logY: logY, logZ: logZ)
            let pauseMarkers = descriptor.hideTimeMarkers ? nil : generatePauseMarkers()
            
            // Prepare final data for main thread
            let finalMin = self.min
            let finalMax = self.max
            let finalBounds = GraphBounds(min: finalMin, max: finalMax)
            let result = GraphDataResult(
                dataSets: currentGraphDataSets,
                bounds: finalBounds,
                grid: grid
            )

            // Update UI on main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.dataManager(self, didUpdateData: result, pauseMarkers: pauseMarkers)
            }
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
                minX += timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: minX))
                maxX += timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: maxX))
            } else if !systemTime && descriptor.linearTime && descriptor.timeOnX && !xMinStrict && !xMaxStrict && !hasZData {
                minX -= timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromLinearTime(t: minX))
                maxX -= timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromLinearTime(t: maxX))
            } else if !logX && !xMinStrict && !xMaxStrict && !hasZData && !descriptor.timeOnX {
                let extraX = (maxX - minX) * 0.05
                maxX += extraX
                minX -= extraX
            }
            
            if systemTime && !descriptor.linearTime && descriptor.timeOnY && !yMinStrict && !yMaxStrict && !hasZData {
                minY += timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: minY))
                maxY += timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: maxY))
            } else if !systemTime && descriptor.linearTime && descriptor.timeOnY && !yMinStrict && !yMaxStrict && !hasZData {
                minY -= timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: minY))
                maxY -= timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: maxY))
            } else if !logY && !yMinStrict && !yMaxStrict && !hasZData && !descriptor.timeOnY {
                let extraY = (maxY - minY) * 0.05
                maxY += extraY
                minY -= extraY
            }
            
            if descriptor.timeOnX && !descriptor.linearTime && !xMinStrict && !xMaxStrict && !hasZData {
                minX = Swift.min(minX, timeReference.getExperimentTimeReferenceByIndex(i: 0))
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
        
        private func generateGrid(logX: Bool, logY: Bool, logZ: Bool) -> GraphGrid {
            let minValue = self.min
            let maxValue = self.max
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

            let mappedXTicks = xTicks.map { tick in
                GraphGridLine(
                    absoluteValue: tick.value,
                    relativeValue: CGFloat(((logX ? log(tick.value) : tick.value) - minX) / xRange),
                    precision: tick.precision
                )
            }

            let mappedYTicks = yTicks.map { tick in
                GraphGridLine(
                    absoluteValue: tick.value,
                    relativeValue: CGFloat(((logY ? log(tick.value) : tick.value) - minY) / yRange),
                    precision: tick.precision
                )
            }
            
            let mappedZTicks = zTicks.map { tick in
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
        
        private func generatePauseMarkers() -> PauseRanges {
            let minValue = self.min
            let maxValue = self.max
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
                
                for i in 0..<timeReference.timeMappings.count {
                    let t = timeReference.getExperimentTimeReferenceByIndex(i: i) +
                           (systemTime ? timeReference.getTotalGapByIndex(i: i) : 0.0)
                    let relativeT = CGFloat((t - minX) / xRange)
                    
                    if t < minX || t > maxX {
                        continue
                    }
                    
                    if timeReference.timeMappings[i].event == .PAUSE {
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
                
                for i in 0..<timeReference.timeMappings.count {
                    let t = timeReference.getExperimentTimeReferenceByIndex(i: i) +
                           (systemTime ? timeReference.getTotalGapByIndex(i: i) : 0.0)
                    let relativeT = CGFloat((t - minY) / yRange)
                    
                    if t < minY || t > maxY {
                        continue
                    }
                    
                    if timeReference.timeMappings[i].event == .START {
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
            if let first = timeReference.timeMappings.first, systemTime && timeOnAxis {
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
            
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.dataManagerDidClearData()
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
    
    var currentBounds: GraphBounds {
        return GraphBounds(min: min, max: max)
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
    func dataManagerDidClearData()
}


struct GraphDataResult {
    let dataSets: [GraphDataSet]
    let bounds: GraphBounds
    let grid: GraphGrid
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

