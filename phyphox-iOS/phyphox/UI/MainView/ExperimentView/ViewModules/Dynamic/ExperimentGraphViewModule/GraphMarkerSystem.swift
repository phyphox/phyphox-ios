//
//  GraphMarkerSystem.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 04.08.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

// MARK: - Graph Marker System
class GraphMarkerSystem {
    weak var delegate: GraphMarkerDelegate?
    
    private let descriptor: GraphViewDescriptor
    private let timeReference: ExperimentTimeReference
    private var markers: [(set: Int, index: Int)] = []
    private var showLinearFit = false
    let markerOverlayView: MarkerOverlayView
    let graphRenderer: GraphRenderer
    
    // Current data context (injected from data manager)
        private var currentDataSets: [GraphDataSet] = []
        private var currentBounds: GraphBounds = GraphBounds(min: GraphPoint3D.zero, max: GraphPoint3D.zero)
        var systemTime: Bool = false
    
    init(descriptor: GraphViewDescriptor, timeReference: ExperimentTimeReference, graphRenderer: GraphRenderer) {
            self.descriptor = descriptor
            self.timeReference = timeReference
            self.markerOverlayView = MarkerOverlayView()
            self.markerOverlayView.clipsToBounds = true
            self.markerOverlayView.isUserInteractionEnabled = false
        self.graphRenderer = graphRenderer
        }
    
    func updateDataContext(dataSets: [GraphDataSet], bounds: GraphBounds, systemTime: Bool) {
            self.currentDataSets = dataSets
            self.currentBounds = bounds
            self.systemTime = systemTime
        }
    
    func handleResizableStateChange(_ state: ResizableViewModuleState) {
        if state != .exclusive {
            markers = []
            showLinearFit = false
        }
    }
    
    func handleTap(at point: CGPoint, dataSets: [GraphDataSet], bounds: GraphBounds, frameSize: CGSize) {
        if let nearestPoint = getIndexOfNearestPoint(at: point, in: dataSets, bounds: bounds, frameSize: frameSize) {
            markers = [nearestPoint]
            showLinearFit = false
        } else {
            markers = []
        }
        refreshMarkers()
    }
    
    func handlePanGesture(translation: CGPoint, state: UIGestureRecognizer.State, at point: CGPoint, dataSets: [GraphDataSet], bounds: GraphBounds, frameSize: CGSize, sender: UIPanGestureRecognizer) {
        if state == .began {
            handleTap(at: sender.location(in: graphRenderer.plotView ) , dataSets: dataSets, bounds: bounds, frameSize: frameSize)
        } else if state == .changed || state == .ended {
            if let nearestPoint = getIndexOfNearestPoint(at: sender.location(in: graphRenderer.plotView ), in: dataSets, bounds: bounds, frameSize: frameSize) {
                print("handlePanGesture nearestPoint: ", nearestPoint)
                print("handlePanGesture actual gz point: ", point)
                if markers.count > 1 {
                    markers[1] = nearestPoint
                } else {
                    markers.append(nearestPoint)
                }
                refreshMarkers()
            }
        }
    }
    
    func getIndexOfNearestPoint(at : CGPoint, in dataSets: [GraphDataSet], bounds: GraphBounds, frameSize: CGSize) -> (set: Int, index: Int)? {
        var minDist = CGFloat.infinity
        var minSet = -1
        var minIndex = -1
        
        let searchRange: CGFloat = 30.0
        let searchRange2 = searchRange*searchRange
        
        let rangeMin = bounds.min
        let rangeMax = bounds.max
        let minX = CGFloat(rangeMin.x)
        let minY = CGFloat(rangeMin.y)
        let maxX = CGFloat(rangeMax.x)
        let maxY = CGFloat(rangeMax.y)
        let frame = frameSize
        let w = frame.width
        let h = frame.height
        
        let hasZData = descriptor.style[0] == .map
        
        func viewXtoDataX(_ x: CGFloat) -> CGFloat {
            return (maxX-minX)*(x/w) + minX
        }
        
        func viewYtoDataY(_ y: CGFloat) -> CGFloat {
            return maxY - (maxY-minY) * (y/h)
        }
        
        func offsetFromDataTime(v: Double) -> Double {
            if systemTime && !descriptor.linearTime {
                return timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: v))
            } else if !systemTime && descriptor.linearTime {
                return -timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromLinearTime(t: v))
            }
            return 0.0
        }
        
        func offsetFromViewTime(v: Double) -> Double {
            if systemTime && !descriptor.linearTime {
                return timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromGappedExperimentTime(t: v))
            } else if !systemTime && descriptor.linearTime {
                print("Index: \(timeReference.getReferenceIndexFromExperimentTime(t: v)) from \(v)")
                return -timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: v))
            }
            return 0.0
        }
        
        var searchRangeMaxX = Swift.max(viewXtoDataX(at.x + searchRange), viewXtoDataX(at.x - searchRange))
        var searchRangeMinX = Swift.min(viewXtoDataX(at.x + searchRange), viewXtoDataX(at.x - searchRange))
        var searchRangeMaxY = Swift.max(viewYtoDataY(at.y + searchRange), viewYtoDataY(at.y - searchRange))
        var searchRangeMinY = Swift.min(viewYtoDataY(at.y + searchRange), viewYtoDataY(at.y - searchRange))
        
        if descriptor.timeOnX {
            let offset = offsetFromViewTime(v: Double(viewXtoDataX(at.x)))
            searchRangeMinX -= CGFloat(offset)
            searchRangeMaxX -= CGFloat(offset)
        }
        if descriptor.timeOnY {
            let offset = offsetFromViewTime(v: Double(viewYtoDataY(at.y)))
            searchRangeMinY -= CGFloat(offset)
            searchRangeMaxY -= CGFloat(offset)
        }
                
        for (i, dataSet) in dataSets.enumerated() {
            
            let n = hasZData ? dataSet.points2D.count : dataSet.points2D.count
            for j in 0..<n {
                if descriptor.style.count > i && (descriptor.style[i] == .hbars || descriptor.style[i] == .vbars) {
                    if j % 6 != 2 && j % 6 != 3 {
                        continue
                    }
                }
                var x = CGFloat(hasZData ? dataSet.points3D[j].x : dataSet.points2D[j].x)
                var y = CGFloat(hasZData ? dataSet.points3D[j].y : dataSet.points2D[j].y)
                
                if x < searchRangeMinX || x > searchRangeMaxX || y < searchRangeMinY || y > searchRangeMaxY {
                    continue
                }
                
                if descriptor.timeOnX {
                    let offset = offsetFromDataTime(v: Double(x))
                    x += CGFloat(offset)
                }
                if descriptor.timeOnY {
                    let offset = offsetFromDataTime(v: Double(y))
                    y += CGFloat(offset)
                }
                
                let vx = (x - minX) / (maxX-minX) * w
                let vy = (maxY - y) / (maxY-minY) * h
                let dx = vx - at.x
                let dy = vy - at.y
                let d = dx*dx+dy*dy
                
                if (d < searchRange2 && d < minDist) {
                    minDist = d
                    minSet = i
                    minIndex = j
                }
            }
        }
        
        if minSet >= 0 && minIndex >= 0 {
            return (set: minSet, index: minIndex)
        } else {
            return nil
        }
    }
    
    private func findNearestPoint(at tapPoint: CGPoint, in dataSets: [GraphDataSet], bounds: GraphBounds, frameSize: CGSize) -> (set: Int, index: Int)? {
        var minDist = CGFloat.infinity
        var minSet = -1
        var minIndex = -1
        
        let searchRange: CGFloat = 30.0
        let searchRange2 = searchRange * searchRange
        
        for (setIndex, dataSet) in dataSets.enumerated() {
            let points = dataSet.points2D.isEmpty ? dataSet.points3D : dataSet.points2D.map { GraphPoint3D(x: $0.x, y: $0.y, z: 0) }
            
            for (pointIndex, point) in points.enumerated() {
                let viewPoint = convertDataPointToViewPoint(point, bounds: bounds, frameSize: frameSize)
                let dx = viewPoint.x - tapPoint.x
                let dy = viewPoint.y - tapPoint.y
                let distance = dx * dx + dy * dy
                
                if distance < searchRange2 && distance < minDist {
                    minDist = distance
                    minSet = setIndex
                    minIndex = pointIndex
                }
            }
        }
        
        if minSet >= 0 && minIndex >= 0 {
            return (set: minSet, index: minIndex)
        }
        return nil
    }
    
    private func convertDataPointToViewPoint(_ point: GraphPoint3D<GLfloat>, bounds: GraphBounds, frameSize: CGSize) -> CGPoint {
        let relativeX = CGFloat((Double(point.x) - bounds.min.x) / (bounds.max.x - bounds.min.x))
        let relativeY = CGFloat(1.0 - (Double(point.y) - bounds.min.y) / (bounds.max.y - bounds.min.y))
        
        return CGPoint(x: relativeX * frameSize.width, y: relativeY * frameSize.height)
    }
    
    private func updateMarkerDisplay(dataSets: [GraphDataSet], bounds: GraphBounds) {
        var relativeCoordinates: [(CGFloat, CGFloat)] = []
        var labelText = ""
        
        let formatter = NumberFormatter()
        formatter.usesSignificantDigits = true
        formatter.minimumSignificantDigits = 4
        formatter.maximumSignificantDigits = 8
        
        if markers.count == 1 {
            let marker = markers[0]
            if marker.set < dataSets.count {
                let dataSet = dataSets[marker.set]
                let point: GraphPoint3D<GLfloat>
                
                if marker.index < dataSet.points2D.count {
                    let p2d = dataSet.points2D[marker.index]
                    point = GraphPoint3D(x: p2d.x, y: p2d.y, z: 0)
                } else if marker.index < dataSet.points3D.count {
                    point = dataSet.points3D[marker.index]
                } else {
                    return
                }
                
                let viewPoint = convertDataPointToViewPoint(point, bounds: bounds, frameSize: markerOverlayView.frame.size)
                let relativePoint = (viewPoint.x / markerOverlayView.frame.width, viewPoint.y / markerOverlayView.frame.height)
                relativeCoordinates.append(relativePoint)
                
                labelText = localize("graph_point_label")
                let x = descriptor.logX ? exp(Double(point.x)) : Double(point.x)
                labelText += "\n    " + (formatter.string(from: x as NSNumber) ?? "N/A") + (descriptor.localizedXUnit != "" ? " " + descriptor.localizedXUnit : "")
                let y = descriptor.logY ? exp(Double(point.y)) : Double(point.y)
                labelText += "\n    " + (formatter.string(from: y as NSNumber) ?? "N/A") + (descriptor.localizedYUnit != "" ? " " + descriptor.localizedYUnit : "")
                if point.z != 0 {
                    let z = descriptor.logZ ? exp(Double(point.z)) : Double(point.z)
                    labelText += "\n    " + (formatter.string(from: z as NSNumber) ?? "N/A") + (descriptor.localizedZUnit != "" ? " " + descriptor.localizedZUnit : "")
                }
            }
        } else if markers.count == 2 {
            // Handle difference calculation for two markers
            // Implementation similar to original code
        }
        
        markerOverlayView.showMarkers = !relativeCoordinates.isEmpty
        markerOverlayView.markers = relativeCoordinates
        
        delegate?.markerSystem(self, shouldShowLabel: labelText.isEmpty ? nil : labelText)
    }
    
    func updateLayout(graphFrame: CGRect) {
        markerOverlayView.frame = graphFrame
    }
    
    func toggleLinearFit() {
        showLinearFit = !showLinearFit
        markers = []
        delegate?.markerSystemDidUpdate(self)
    }
    
    
    func clearMarkers() {
        markers = []
        markerOverlayView.markers = []
        delegate?.markerSystem(self, shouldShowLabel: nil)
    }
    

    var isShowingLinearFit: Bool { return showLinearFit }
}


extension GraphMarkerSystem {
    
    func refreshMarkers(){
        let markerData = collectMarkerData()
        let numberFormatter = createNumberFormatter()
        
        switch markerData.count {
        case 1:
            showSinglePointMarker(markerData: markerData, formatter: numberFormatter)
            delegate?.markerSystem(self, shouldPositionLabel: ( markerData.averageRelativeX,currentBounds.min.x))
        case 2:
            showDifferenceMarker(markerData: markerData, formatter: numberFormatter)
            delegate?.markerSystem(self, shouldPositionLabel: (markerData.averageRelativeX,currentBounds.min.x))
        default:
            if showLinearFit {
                showLinearFitMarker(formatter: numberFormatter)
                delegate?.markerSystem(self, shouldPositionLabel: (markerData.averageRelativeX,currentBounds.min.x))
            } else {
                clearMarkers()
            }
        }
        
    }
    
    private func showSinglePointMarker(markerData: MarkerData, formatter: NumberFormatter) {
        self.markerOverlayView.showMarkers = true
        self.markerOverlayView.markers = markerData.relativeCoordinates
        
        let labelText = buildSinglePointLabel(
                x: markerData.xValues[0],
                y: markerData.yValues[0],
                z: markerData.zValues[0],
                formatter: formatter
            )
        
        delegate?.markerSystem(self, shouldShowLabel: labelText)
    }
    
    private func showDifferenceMarker(markerData: MarkerData, formatter: NumberFormatter) {
        markerOverlayView.showMarkers = true
        markerOverlayView.markers = markerData.relativeCoordinates
        
        let labelText = buildDifferenceLabel(
                x1: markerData.xValues[0], x2: markerData.xValues[1],
                y1: markerData.yValues[0], y2: markerData.yValues[1],
                z1: markerData.zValues[0], z2: markerData.zValues[1],
                formatter: formatter
            )
        delegate?.markerSystem(self, shouldShowLabel: labelText)
        
    }
    
    private func showLinearFitMarker(formatter: NumberFormatter) {
        guard let dataSet = currentDataSets.first, dataSet.points2D.count >= 2 else {
               clearMarkers()
               return
           }
        
        let (slope, intercept) = calculateLinearRegression(dataSet.points2D)
        
        let fitMarkerData = createLinearFitMarkerData(slope: slope, intercept: intercept)
        
        self.markerOverlayView.showMarkers = false
        self.markerOverlayView.markers = fitMarkerData.relativeCoordinates
        
        let labelText = buildLinearFitLabel(slope: slope, intercept: intercept, formatter: formatter)
        delegate?.markerSystem(self, shouldShowLabel: labelText)
        
        
    }
    
    
    private struct MarkerData {
        let relativeCoordinates: [(CGFloat, CGFloat)]
        let xValues: [GLfloat]
        let yValues: [GLfloat]
        let zValues: [GLfloat]
        let averageRelativeX: CGFloat
        let minimumRelativeY: CGFloat
        let count: Int
    }
    
    private func collectMarkerData() -> MarkerData {
        var relativeCoordinates: [(CGFloat, CGFloat)] = []
        var xValues: [GLfloat] = []
        var yValues: [GLfloat] = []
        var zValues: [GLfloat] = []
        var totalRelativeX = CGFloat(0.0)
        var minimumRelativeY = CGFloat.infinity
        var count = 0
        
        let minPoint = currentBounds.min
        let maxPoint = currentBounds.max
        
        for marker in markers {
            guard marker.set < currentDataSets.count else { continue }
            
            let dataset = currentDataSets[marker.set]
            let coordinates = extractCoordinates(from: dataset, at: marker.index)
            
            guard let (x, y, z) = coordinates else { continue }
            
            let relativeCoordinate = calculateRelativeCoordinate(x: x, y: y, min: minPoint, max: maxPoint)
            
            xValues.append(x)
            yValues.append(y)
            zValues.append(z)
            
            relativeCoordinates.append(relativeCoordinate)
            
            totalRelativeX += relativeCoordinate.0
            count += 1
                    
            if relativeCoordinate.1 < minimumRelativeY {
                minimumRelativeY = relativeCoordinate.1
            }
            
            
        }
        let averageRelativeX = count > 0 ? totalRelativeX / CGFloat(count) : 0
        
        
        return MarkerData(
                relativeCoordinates: relativeCoordinates,
                xValues: xValues,
                yValues: yValues,
                zValues: zValues,
                averageRelativeX: averageRelativeX,
                minimumRelativeY: minimumRelativeY,
                count: count
            )
    }
    
    private func extractCoordinates(from dataSet: GraphDataSet, at index: Int) -> (GLfloat, GLfloat, GLfloat)? {
        if index < dataSet.points2D.count {
            let point = dataSet.points2D[index]
            return (point.x, point.y, GLfloat.nan)
        } else if index < dataSet.points3D.count {
            let point = dataSet.points3D[index]
            return (point.x, point.y, point.z)
        }
        return nil
    }
    
    private func calculateRelativeCoordinate(x: GLfloat, y: GLfloat,min: GraphPoint3D<Double>, max: GraphPoint3D<Double>) -> (CGFloat, CGFloat) {
        
        let offsetX = calculateTimeOffset(value: x, isXAxis: true)
        let offsetY = calculateTimeOffset(value: y, isXAxis: false)
        
        let relativeX = CGFloat((Double(x) + offsetX - min.x) / (max.x - min.x))
        let relativeY = CGFloat((max.y - Double(y) - offsetY) / (max.y - min.y))
        
        return (relativeX, relativeY)
        
    }
    
    private func calculateTimeOffset(value: GLfloat, isXAxis: Bool) -> Double {
        let isTimeAxis = isXAxis ? descriptor.timeOnX : descriptor.timeOnY
        
        guard isTimeAxis else { return 0.0 }
        
        if systemTime && !descriptor.linearTime {
            return timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: Double(value)))
        } else if !systemTime && descriptor.linearTime {
            return -timeReference.getTotalGapByIndex(
                i: timeReference.getReferenceIndexFromLinearTime(t: Double(value))
            )
        }
        
        return 0.0
        
        
    }
    
    private func createNumberFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.usesSignificantDigits = true
        formatter.minimumSignificantDigits = 4
        formatter.maximumSignificantDigits = 8
        return formatter
    }
    
    private func buildSinglePointLabel(x: GLfloat, y: GLfloat, z: GLfloat, formatter: NumberFormatter) -> String {
        let hasZData = descriptor.style[0] == .map
        
        var labelText = localize("graph_point_label")
        
        let convertedX = convertValue(x, isLogarithmic: descriptor.logX)
        labelText += "\n    " + formatValue(convertedX, formatter: formatter) + formatUnit(descriptor.localizedXUnit)
        
        let convertedY = convertValue(y, isLogarithmic: descriptor.logY)
            labelText += "\n    " + formatValue(convertedY, formatter: formatter) + formatUnit(descriptor.localizedYUnit)
            
        if hasZData {
            let convertedZ = convertValue(z, isLogarithmic: descriptor.logZ)
            labelText += "\n    " + formatValue(convertedZ, formatter: formatter) + formatUnit(descriptor.localizedZUnit)
        }
            
        return labelText
        
    }
    
    private func buildDifferenceLabel(x1: GLfloat, x2: GLfloat, y1: GLfloat, y2: GLfloat, z1: GLfloat, z2: GLfloat, formatter: NumberFormatter) -> String {
        let hasZData = descriptor.style[0] == .map
        
        var labelText = localize("graph_difference_label")
        
        let convertedX1 = convertValue(x1, isLogarithmic: descriptor.logX)
        let convertedX2 = convertValue(x2, isLogarithmic: descriptor.logX)
        let dx = abs(convertedX1 - convertedX2)
        labelText += "\n    " + formatValue(dx, formatter: formatter) + formatUnit(descriptor.localizedXUnit)
        
        let convertedY1 = convertValue(y1, isLogarithmic: descriptor.logY)
        let convertedY2 = convertValue(y2, isLogarithmic: descriptor.logY)
        let dy = abs(convertedY1 - convertedY2)
        labelText += "\n    " + formatValue(dy, formatter: formatter) + formatUnit(descriptor.localizedYUnit)
        
        if hasZData {
            let convertedZ1 = convertValue(z1, isLogarithmic: descriptor.logZ)
            let convertedZ2 = convertValue(z2, isLogarithmic: descriptor.logZ)
            let dz = abs(convertedZ1 - convertedZ2)
            labelText += "\n    " + formatValue(dz, formatter: formatter) + formatUnit(descriptor.localizedZUnit)
        }
        
        labelText += "\n" + localize("graph_slope_label")
        let slope = (convertedY1 - convertedY2) / (convertedX1 - convertedX2)
        labelText += "\n    " + formatValue(slope, formatter: formatter) + " " + descriptor.localizedYXUnit
        
        return labelText
    }
    
    private func buildLinearFitLabel(slope: GLfloat, intercept: GLfloat, formatter: NumberFormatter) -> String {
        var labelText = localize("graph_fit_label")
        labelText += "\na = " + formatValue(slope, formatter: formatter) + " " + descriptor.localizedYXUnit
        labelText += "\nb = " + formatValue(intercept, formatter: formatter) + formatUnit(descriptor.localizedYUnit)
        return labelText
    }
    
    private func convertValue(_ value: GLfloat, isLogarithmic: Bool) -> GLfloat {
        return isLogarithmic ? exp(value) : value
    }

    private func formatValue(_ value: GLfloat, formatter: NumberFormatter) -> String {
        return formatter.string(from: value as NSNumber) ?? "N/A"
    }

    private func formatUnit(_ unit: String) -> String {
        return unit.isEmpty ? "" : " " + unit
    }
    
    private func createLinearFitMarkerData(slope: GLfloat, intercept: GLfloat) -> MarkerData {
        let minPoint = currentBounds.min
        let maxPoint = currentBounds.max
        
        // Calculate the two endpoints of the fit line
        let x1 = GLfloat(minPoint.x)
        let y1 = slope * x1 + intercept
        let coord1 = calculateRelativeCoordinate(x: x1, y: y1, min: minPoint, max: maxPoint)
        
        let x2 = GLfloat(maxPoint.x)
        let y2 = slope * x2 + intercept
        let coord2 = calculateRelativeCoordinate(x: x2, y: y2, min: minPoint, max: maxPoint)
        
        // Build the marker data similar to appendMarker logic
        let relativeCoordinates = [coord1, coord2]
        let xValues = [x1, x2]
        let yValues = [y1, y2]
        let zValues = [GLfloat.nan, GLfloat.nan]
        
        // Calculate average relative X and minimum relative Y
        let averageRelativeX = (coord1.0 + coord2.0) / 2.0
        let minimumRelativeY = Swift.min(coord1.1, coord2.1)
        
        return MarkerData(
            relativeCoordinates: relativeCoordinates,
            xValues: xValues,
            yValues: yValues,
            zValues: zValues,
            averageRelativeX: averageRelativeX,
            minimumRelativeY: minimumRelativeY,
            count: 2
        )
    }
    
}

extension GraphMarkerSystem {
    func refreshMarkersOld() {
        var relativeCoordinates: [(CGFloat, CGFloat)] = []
        
        let min = currentBounds.min
        let max = currentBounds.max
        
        var xlist: [GLfloat] = []
        var ylist: [GLfloat] = []
        var zlist: [GLfloat] = []
        var avgRX = CGFloat(0.0)
        var minRY = CGFloat.infinity
        var n = 0
        
        func appendMarker(_ x: GLfloat, _ y: GLfloat, _ z: GLfloat) {
            let offsetX: Double
            let offsetY: Double
            
            if descriptor.timeOnX && systemTime && !descriptor.linearTime {
                offsetX = timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: Double(x)))
            } else if descriptor.timeOnX && !systemTime && descriptor.linearTime {
                offsetX = -timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromLinearTime(t: Double(x)))
            } else {
                offsetX = 0.0
            }
            
            if descriptor.timeOnY && systemTime && !descriptor.linearTime {
                offsetY = timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromExperimentTime(t: Double(y)))
            } else if descriptor.timeOnY && !systemTime && descriptor.linearTime {
                offsetY = -timeReference.getTotalGapByIndex(i: timeReference.getReferenceIndexFromLinearTime(t: Double(y)))
            } else {
                offsetY = 0.0
            }
            
            let rx = CGFloat((Double(x) + offsetX - min.x) / (max.x - min.x))
            let ry = CGFloat((max.y - Double(y) - offsetY) / (max.y - min.y))
            
            xlist.append(x)
            ylist.append(y)
            zlist.append(z)
            
            avgRX += rx
            n += 1
            if ry < minRY {
                minRY = ry
            }
            
            relativeCoordinates.append((rx, ry))
        }
        
        // Process markers
        for marker in markers {
            if marker.set < currentDataSets.count {
                let dataSet = currentDataSets[marker.set]
                
                let x: GLfloat, y: GLfloat, z: GLfloat
                if marker.index < dataSet.points2D.count {
                    x = dataSet.points2D[marker.index].x
                    y = dataSet.points2D[marker.index].y
                    z = GLfloat.nan
                } else if marker.index < dataSet.points3D.count {
                    x = dataSet.points3D[marker.index].x
                    y = dataSet.points3D[marker.index].y
                    z = dataSet.points3D[marker.index].z
                } else {
                    continue
                }
                
                appendMarker(x, y, z)
            }
        }
        
        let formatter = NumberFormatter()
        formatter.usesSignificantDigits = true
        formatter.minimumSignificantDigits = 4
        formatter.maximumSignificantDigits = 8
        
        let hasZData = descriptor.style[0] == .map
        
        if n == 1 {
            markerOverlayView.showMarkers = true
            markerOverlayView.markers = relativeCoordinates
            
            var labelText = localize("graph_point_label")
            let x = (descriptor.logX ? exp(Double(xlist[0])) : Double(xlist[0]))
            labelText += "\n    " + (formatter.string(from: x as NSNumber) ?? "N/A") +
                        (descriptor.localizedXUnit != "" ? " " + descriptor.localizedXUnit : "")
            let y = (descriptor.logY ? exp(Double(ylist[0])) : Double(ylist[0]))
            labelText += "\n    " + (formatter.string(from: y as NSNumber) ?? "N/A") +
                        (descriptor.localizedYUnit != "" ? " " + descriptor.localizedYUnit : "")
            if hasZData {
                let z = (descriptor.logZ ? exp(Double(zlist[0])) : Double(zlist[0]))
                labelText += "\n    " + (formatter.string(from: z as NSNumber) ?? "N/A") +
                            (descriptor.localizedZUnit != "" ? " " + descriptor.localizedZUnit : "")
            }
            delegate?.markerSystem(self, shouldShowLabel: labelText)
            
        } else if n == 2 {
            markerOverlayView.showMarkers = true
            markerOverlayView.markers = relativeCoordinates
            
            var labelText = localize("graph_difference_label")
            let dx = abs((descriptor.logX ? exp(Double(xlist[0])) : Double(xlist[0])) -
                        (descriptor.logX ? exp(Double(xlist[1])) : Double(xlist[1])))
            labelText += "\n    " + (formatter.string(from: dx as NSNumber) ?? "N/A") +
                        (descriptor.localizedXUnit != "" ? " " + descriptor.localizedXUnit : "")
            let dy = abs((descriptor.logY ? exp(Double(ylist[0])) : Double(ylist[0])) -
                        (descriptor.logY ? exp(Double(ylist[1])) : Double(ylist[1])))
            labelText += "\n    " + (formatter.string(from: dy as NSNumber) ?? "N/A") +
                        (descriptor.localizedYUnit != "" ? " " + descriptor.localizedYUnit : "")
            if hasZData {
                let dz = abs((descriptor.logZ ? exp(Double(zlist[0])) : Double(zlist[0])) -
                            (descriptor.logZ ? exp(Double(zlist[1])) : Double(zlist[1])))
                labelText += "\n    " + (formatter.string(from: dz as NSNumber) ?? "N/A") +
                            (descriptor.localizedZUnit != "" ? " " + descriptor.localizedZUnit : "")
            }
            labelText += "\n" + localize("graph_slope_label")
            let slope = ((descriptor.logY ? exp(Double(ylist[0])) : Double(ylist[0])) -
                        (descriptor.logY ? exp(Double(ylist[1])) : Double(ylist[1]))) /
                       ((descriptor.logX ? exp(Double(xlist[0])) : Double(xlist[0])) -
                        (descriptor.logX ? exp(Double(xlist[1])) : Double(xlist[1])))
            labelText += "\n    " + (formatter.string(from: slope as NSNumber) ?? "N/A") + " " + descriptor.localizedYXUnit
            
            delegate?.markerSystem(self, shouldShowLabel: labelText)
            
        } else if showLinearFit {
            if let dataSet = currentDataSets.first, dataSet.points2D.count >= 2 {
                let (a, b) = calculateLinearRegression(dataSet.points2D)
                
                let x1 = GLfloat(min.x)
                let y1 = a * GLfloat(min.x) + b
                appendMarker(x1, y1, GLfloat.nan)
                let x2 = GLfloat(max.x)
                let y2 = a * GLfloat(max.x) + b
                appendMarker(x2, y2, GLfloat.nan)
                
                markerOverlayView.showMarkers = false
                markerOverlayView.markers = relativeCoordinates
                
                var labelText = localize("graph_fit_label")
                labelText += "\na = " + (formatter.string(from: a as NSNumber) ?? "N/A") + " " + descriptor.localizedYXUnit
                labelText += "\nb = " + (formatter.string(from: b as NSNumber) ?? "N/A") +
                            (descriptor.localizedYUnit != "" ? " " + descriptor.localizedYUnit : "")
                delegate?.markerSystem(self, shouldShowLabel: labelText)
            } else {
                delegate?.markerSystem(self, shouldShowLabel: nil)
                markerOverlayView.markers = []
            }
        } else {
            delegate?.markerSystem(self, shouldShowLabel: nil)
            markerOverlayView.markers = []
        }
        
        // Position the marker label if we have markers and a delegate provided a label
                if n > 0 {
                    avgRX /= CGFloat(n)
                    delegate?.markerSystem(self, shouldPositionLabel: (avgRX, minRY))
                }
    }
    
    
    
    private func calculateLinearRegression(_ data: [GraphPoint2D<GLfloat>]) -> (GLfloat, GLfloat) {
        var sumX: GLfloat = 0.0
        var sumX2: GLfloat = 0.0
        var sumY: GLfloat = 0.0
        var sumY2: GLfloat = 0.0
        var sumXY: GLfloat = 0.0
        
        for point in data {
            sumX += point.x
            sumX2 += point.x * point.x
            sumY += point.y
            sumY2 += point.y * point.y
            sumXY += point.x * point.y
        }
        
        let norm = GLfloat(data.count) * sumX2 - sumX * sumX
        guard norm != 0 else {
            return (GLfloat.nan, GLfloat.nan)
        }
        
        let a = (GLfloat(data.count) * sumXY - sumX * sumY) / norm
        let b = (sumY * sumX2 - sumX * sumXY) / norm
        
        return (a, b)
    }
}

protocol GraphMarkerDelegate: AnyObject {
    func markerSystemDidUpdate(_ markerSystem: GraphMarkerSystem)
    func markerSystem(_ markerSystem: GraphMarkerSystem, shouldShowLabel text: String?)
    func markerSystem(_ markerSystem: GraphMarkerSystem, shouldPositionLabel position: (CGFloat, CGFloat))
}
