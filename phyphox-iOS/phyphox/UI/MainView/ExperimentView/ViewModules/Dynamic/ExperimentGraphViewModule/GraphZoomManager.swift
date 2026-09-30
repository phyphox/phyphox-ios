//
//  GraphZoomManager.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 04.08.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

// MARK: - Graph Zoom Manager
class GraphZoomManager {
    weak var delegate: GraphZoomDelegate?
    
    private let descriptor: GraphViewDescriptor
    private let dataManager: GraphDataManager
    private var zoomMin: GraphPoint3D<Double>?
    private var zoomMax: GraphPoint3D<Double>?
    private var zoomFollows = false
    
    // Pan/pinch state tracking
    private var panStartMin: GraphPoint2D<Double>?
    private var panStartMax: GraphPoint2D<Double>?
    private var pinchOrigin: GraphPoint2D<Double>?
    private var pinchScale: GraphPoint2D<Double>?
    private var pinchTouchScale: GraphPoint2D<CGFloat>?
    private var zPanStartMin: Double?
    private var zPanStartMax: Double?
    private var zPinchOrigin: Double?
    private var zPinchScale: Double?
    private var zPinchTouchScale: CGFloat?
    
    var previouslyKept = false
    var hasCustomZoom: Bool { zoomMin != nil || zoomMax != nil || zoomFollows != descriptor.followX }
    var currentZoomBounds: GraphBounds {
        return GraphBounds(
            min: zoomMin ?? GraphPoint3D.zero,
            max: zoomMax ?? GraphPoint3D.zero
        )
    }
    var isZoomFollows: Bool { return zoomFollows }
    
    init(descriptor: GraphViewDescriptor, dataManager: GraphDataManager) {
        self.descriptor = descriptor
        self.dataManager = dataManager
        self.zoomFollows = descriptor.followX
        
        if descriptor.followX {
            zoomMin = GraphPoint3D(x: descriptor.minX, y: Double.nan, z: Double.nan)
            zoomMax = GraphPoint3D(x: descriptor.maxX, y: Double.nan, z: Double.nan)
        }
    }
    
    func resetZoom() {
        zoomFollows = descriptor.followX
        if descriptor.followX {
            zoomMin = GraphPoint3D(x: descriptor.minX, y: Double.nan, z: Double.nan)
            zoomMax = GraphPoint3D(x: descriptor.maxX, y: Double.nan, z: Double.nan)
        } else {
            zoomMin = nil
            zoomMax = nil
        }
        delegate?.zoomManagerDidUpdate(self)
    }
    
    func toggleFollow() {
        if !zoomFollows && (zoomMin == nil || zoomMax == nil) {
            zoomMin = GraphPoint3D(x: Double.nan, y: Double.nan, z: Double.nan)
            zoomMax = GraphPoint3D(x: Double.nan, y: Double.nan, z: Double.nan)
        }
        zoomFollows = !zoomFollows
        delegate?.zoomManagerDidUpdate(self)
    }
    
    func applyPanGesture(translation: CGPoint, bounds: GraphBounds, frameSize: CGSize, state: UIGestureRecognizer.State) {
        zoomFollows = false
        
        let min = GraphPoint2D(x: bounds.min.x, y: bounds.min.y)
        let max = GraphPoint2D(x: bounds.max.x, y: bounds.max.y)
        
        if state == .began {
            panStartMin = min
            panStartMax = max
        }
        
        guard let startMin = panStartMin, let startMax = panStartMax else { return }
        
        let dx = Double(translation.x / frameSize.width) * (max.x - min.x)
        let dy = Double(translation.y / frameSize.height) * (min.y - max.y)
        
        zoomMin = GraphPoint3D(
            x: limitRange(startMin.x - dx, isLog: dataManager.logX),
            y: limitRange(startMin.y - dy, isLog: dataManager.logY),
            z: zoomMin?.z ?? Double.nan
        )
        zoomMax = GraphPoint3D(
            x: limitRange(startMax.x - dx, isLog: dataManager.logX),
            y: limitRange(startMax.y - dy, isLog: dataManager.logY),
            z: zoomMax?.z ?? Double.nan
        )
        
        delegate?.zoomManagerDidUpdate(self)
    }
    
    func applyPinchGesture(scale: CGFloat, center: CGPoint, touches: (CGPoint, CGPoint), bounds: GraphBounds, frameSize: CGSize, state: UIGestureRecognizer.State) {
        zoomFollows = false
        
        let min = bounds.min
        let max = bounds.max
        
        let centerX = (touches.0.x + touches.1.x) / 2.0
        let centerY = (touches.0.y + touches.1.y) / 2.0
        
        if state == .began {
            pinchTouchScale = GraphPoint2D(
                x: abs(touches.0.x - touches.1.x) / scale,
                y: abs(touches.0.y - touches.1.y) / scale
            )
            pinchScale = GraphPoint2D(x: max.x - min.x, y: max.y - min.y)
            pinchOrigin = GraphPoint2D(
                x: min.x + Double(centerX) / Double(frameSize.width) * pinchScale!.x,
                y: max.y - Double(centerY) / Double(frameSize.height) * pinchScale!.y
            )
        }
        
        guard let origin = pinchOrigin, let pScale = pinchScale, let touchScale = pinchTouchScale else { return }
        
        let dx = abs(touches.0.x - touches.1.x)
        let dy = abs(touches.0.y - touches.1.y)
        
        var scaleX = Double(touchScale.x / dx) * pScale.x
        var scaleY = Double(touchScale.y / dy) * pScale.y
        
        scaleX = Swift.min(scaleX, 20 * pScale.x)
        scaleY = Swift.min(scaleY, 20 * pScale.y)
        
        let zoomMinX = origin.x - Double(centerX) / Double(frameSize.width) * scaleX
        let zoomMaxX = zoomMinX + scaleX
        let zoomMaxY = origin.y + Double(centerY) / Double(frameSize.height) * scaleY
        let zoomMinY = zoomMaxY - scaleY
        
        zoomMin = GraphPoint3D(
            x: limitRange(zoomMinX, isLog: dataManager.logX),
            y: limitRange(zoomMinY, isLog: dataManager.logY),
            z: zoomMin?.z ?? Double.nan
        )
        zoomMax = GraphPoint3D(
            x: limitRange(zoomMaxX, isLog: dataManager.logX),
            y: limitRange(zoomMaxY, isLog: dataManager.logY),
            z: zoomMax?.z ?? Double.nan
        )
        
        delegate?.zoomManagerDidUpdate(self)
    }
    
    func applyZPanGesture(translation: CGPoint, bounds: GraphBounds, frameSize: CGSize, state: UIGestureRecognizer.State) {
        let min = bounds.min.z
        let max = bounds.max.z
        
        if state == .began {
            zPanStartMin = min
            zPanStartMax = max
        }
        
        guard let startMin = zPanStartMin, let startMax = zPanStartMax else { return }
        
        let dz = Double(translation.x / frameSize.width) * (max - min)
        
        zoomMin = GraphPoint3D(
            x: zoomMin?.x ?? Double.nan,
            y: zoomMin?.y ?? Double.nan,
            z: startMin - dz
        )
        zoomMax = GraphPoint3D(
            x: zoomMax?.x ?? Double.nan,
            y: zoomMax?.y ?? Double.nan,
            z: startMax - dz
        )
        
        delegate?.zoomManagerDidUpdate(self)
    }
    
    func applyZPinchGesture(scale: CGFloat, center: CGPoint, touches: (CGPoint, CGPoint), bounds: GraphBounds, frameSize: CGSize, state: UIGestureRecognizer.State) {
        let min = bounds.min.z
        let max = bounds.max.z
        
        let centerX = (touches.0.x + touches.1.x) / 2.0
        
        if state == .began {
            zPinchTouchScale = abs(touches.0.x - touches.1.x) / scale
            zPinchScale = max - min
            zPinchOrigin = min + Double(centerX) / Double(frameSize.width) * zPinchScale!
        }
        
        guard let origin = zPinchOrigin, let pScale = zPinchScale, let touchScale = zPinchTouchScale else { return }
        
        let dz = abs(touches.0.x - touches.1.x)
        var scaleZ = Double(touchScale / dz) * pScale
        
        scaleZ = Swift.min(scaleZ, 20 * pScale)
        
        let zoomMinZ = origin - Double(centerX) / Double(frameSize.width) * scaleZ
        let zoomMaxZ = zoomMinZ + scaleZ
        
        zoomMin = GraphPoint3D(
            x: zoomMin?.x ?? Double.nan,
            y: zoomMin?.y ?? Double.nan,
            z: zoomMinZ
        )
        zoomMax = GraphPoint3D(
            x: zoomMax?.x ?? Double.nan,
            y: zoomMax?.y ?? Double.nan,
            z: zoomMaxZ
        )
        
        delegate?.zoomManagerDidUpdate(self)
    }
    
    func applyZoomSettings(modeX: ApplyZoomAction, applyToX: ApplyZoomTarget, modeY: ApplyZoomAction, applyToY: ApplyZoomTarget) {
        if applyToX == .this {
            switch modeX {
            case .reset:
                zoomFollows = descriptor.followX
                if descriptor.followX {
                    zoomMin = GraphPoint3D(x: descriptor.minX, y: zoomMin?.y ?? Double.nan, z: Double.nan)
                    zoomMax = GraphPoint3D(x: descriptor.maxX, y: zoomMax?.y ?? Double.nan, z: Double.nan)
                } else {
                    zoomMax = GraphPoint3D(x: Double.nan, y: zoomMax?.y ?? Double.nan, z: Double.nan)
                    zoomMin = GraphPoint3D(x: Double.nan, y: zoomMin?.y ?? Double.nan, z: Double.nan)
                }
            case .follow:
                zoomFollows = true
            default:
                break
            }
        }
        
        if applyToY == .this {
            switch modeY {
            case .reset:
                zoomMax = GraphPoint3D(x: zoomMax?.x ?? Double.nan, y: Double.nan, z: Double.nan)
                zoomMin = GraphPoint3D(x: zoomMin?.x ?? Double.nan, y: Double.nan, z: Double.nan)
            default:
                break
            }
        }
        
        delegate?.zoomManagerDidUpdate(self)
    }
    
    //A range received from another graph (already converted to this graph's units); an axis given as nil keeps its zoom
    func applyExternalZoom(x: (min: Double, max: Double)?, y: (min: Double, max: Double)?) {
        if let x = x, x.min.isFinite, x.max.isFinite, x.min < x.max {
            zoomMin = GraphPoint3D(x: x.min, y: zoomMin?.y ?? Double.nan, z: zoomMin?.z ?? Double.nan)
            zoomMax = GraphPoint3D(x: x.max, y: zoomMax?.y ?? Double.nan, z: zoomMax?.z ?? Double.nan)
        }
        if let y = y, y.min.isFinite, y.max.isFinite, y.min < y.max {
            zoomMin = GraphPoint3D(x: zoomMin?.x ?? Double.nan, y: y.min, z: zoomMin?.z ?? Double.nan)
            zoomMax = GraphPoint3D(x: zoomMax?.x ?? Double.nan, y: y.max, z: zoomMax?.z ?? Double.nan)
        }
        delegate?.zoomManagerDidUpdate(self)
    }

    private func limitRange(_ v: Double?, isLog: Bool) -> Double {
        guard let v = v, v.isFinite else {
            return Double.nan
        }
        let limit = isLog ? log(1e38) : 1e38
        return Swift.max(Swift.min(v, limit), -limit)
    }
}

protocol GraphZoomDelegate: AnyObject {
    func zoomManagerDidUpdate(_ manager: GraphZoomManager)
}


extension GraphZoomManager {
    func notifyDataManager(_ dataManager: GraphDataManager) {
        dataManager.updateZoomState(
            min: zoomMin,
            max: zoomMax,
            follows: zoomFollows
        )
    }
}

// MARK: - ZoomableViewModule Implementation
extension ExperimentGraphView {
    func applyZoom(modeX: ApplyZoomAction, applyToX: ApplyZoomTarget, targetX: String?, unitX: Unit?, modeY: ApplyZoomAction, applyToY: ApplyZoomTarget, targetY: String?, unitY: Unit?, zoomMin: GraphPoint2D<Double>, zoomMax: GraphPoint2D<Double>, systemTime: Bool) {
        
        var applyX = false
        var applyY = false
        
        switch applyToX {
        case .this, .sameAxis:
            applyX = true
        case .sameUnit:
            if let unit = unitX, ExperimentGraphView.unitMatches(axisUnit: descriptor.xAxisUnit, unit) {
                applyX = true
            }
        case .sameVariable:
            if targetX == descriptor.xInputBuffers[0]?.name {
                applyX = true
            }
        case .none:
            break
        }
        
        switch applyToY {
        case .this, .sameAxis:
            applyY = true
        case .sameUnit:
            if let unit = unitY, ExperimentGraphView.unitMatches(axisUnit: descriptor.yAxisUnit, unit) {
                applyY = true
            }
        case .sameVariable:
            if targetY == descriptor.yInputBuffers[0].name {
                applyY = true
            }
        case .none:
            break
        }
        
        if applyX || applyY {
            zoomManager.applyZoomSettings(modeX: applyX ? modeX : .none, applyToX: applyX ? applyToX : .none, modeY: applyY ? modeY : .none, applyToY: applyY ? applyToY : .none)
        }

        //A kept or followed range from another graph, converted from the sending graph's unit into this one's where
        //both are references (a log axis works in log space, where a unit conversion does not apply)
        func range(_ min: Double, _ max: Double, from: Unit?, to: Unit, log: Bool) -> (min: Double, max: Double) {
            guard !log, let from = from?.id, let to = to.id else { return (min, max) }
            return (Units.convert(min, from: from, to: to), Units.convert(max, from: from, to: to))
        }
        let externalX = applyX && applyToX != .this && (modeX == .keep || modeX == .follow) ? range(zoomMin.x, zoomMax.x, from: unitX, to: descriptor.xAxisUnit, log: dataManager.logX) : nil
        let externalY = applyY && applyToY != .this && modeY == .keep ? range(zoomMin.y, zoomMax.y, from: unitY, to: descriptor.yAxisUnit, log: dataManager.logY) : nil
        if externalX != nil || externalY != nil {
            zoomManager.applyExternalZoom(x: externalX, y: externalY)
        }
        
        if (applyX && descriptor.timeOnX) || (applyY && descriptor.timeOnY) {
            self.systemTime = systemTime
        }
    }

    //A referenced unit matches every axis of the same quantity, text matches by equal text (units.md, "Linked zoom")
    static func unitMatches(axisUnit: Unit, _ unit: Unit) -> Bool {
        if unit.isReference {
            return Units.sameQuantity(axisUnit.id, unit.id)
        }
        return axisUnit.id == nil && axisUnit.text == unit.text
    }
}

extension ExperimentGraphView: GraphZoomDelegate {
    func zoomManagerDidUpdate(_ manager: GraphZoomManager) {
        manager.notifyDataManager(dataManager)
        dataManager.setNeedsUpdate()
    }
}

extension ExperimentGraphView: ApplyZoomDialogResultDelegate {
    func applyZoomDialogResult(modeX: ApplyZoomAction, applyToX: ApplyZoomTarget, modeY: ApplyZoomAction, applyToY: ApplyZoomTarget) {
        zoomManager.previouslyKept = !(modeX == .reset && modeY == .reset)
        layoutDelegate?.restoreLayout()
        
        // Apply zoom settings
        zoomManager.applyZoomSettings(modeX: modeX, applyToX: applyToX, modeY: modeY, applyToY: applyToY)
        
        // Propagate to other graphs if needed
        if applyToX != .this || applyToY != .this {
            propagateZoomToOtherGraphs(modeX: modeX, applyToX: applyToX, modeY: modeY, applyToY: applyToY)
        }
    }
    
    private func propagateZoomToOtherGraphs(modeX: ApplyZoomAction, applyToX: ApplyZoomTarget, modeY: ApplyZoomAction, applyToY: ApplyZoomTarget) {
        let targetX = applyToX == .sameVariable ? descriptor.xInputBuffers[0]?.name : nil
        let targetY = applyToY == .sameVariable ? descriptor.yInputBuffers[0].name : nil
        
        let zoomBounds = zoomManager.currentZoomBounds
        zoomDelegate?.applyZoom(
            modeX: applyToX == .this ? .none : modeX,
            applyToX: applyToX == .this ? .none : applyToX,
            targetX: targetX,
            unitX: applyToX == .sameUnit ? descriptor.xAxisUnit : nil,
            modeY: applyToY == .this ? .none : modeY,
            applyToY: applyToY == .this ? .none : applyToY,
            targetY: targetY,
            unitY: applyToY == .sameUnit ? descriptor.yAxisUnit : nil,
            zoomMin: GraphPoint2D(x: zoomBounds.min.x, y: zoomBounds.min.y),
            zoomMax: GraphPoint2D(x: zoomBounds.max.x, y: zoomBounds.max.y),
            systemTime: systemTime
        )
    }
}
