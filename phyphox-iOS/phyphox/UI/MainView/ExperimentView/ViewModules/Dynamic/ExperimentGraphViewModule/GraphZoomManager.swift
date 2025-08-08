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
    
    init(descriptor: GraphViewDescriptor) {
        self.descriptor = descriptor
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
            x: limitRange(startMin.x - dx, isLog: descriptor.logX),
            y: limitRange(startMin.y - dy, isLog: descriptor.logY),
            z: zoomMin?.z ?? Double.nan
        )
        zoomMax = GraphPoint3D(
            x: limitRange(startMax.x - dx, isLog: descriptor.logX),
            y: limitRange(startMax.y - dy, isLog: descriptor.logY),
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
            x: limitRange(zoomMinX, isLog: descriptor.logX),
            y: limitRange(zoomMinY, isLog: descriptor.logY),
            z: zoomMin?.z ?? Double.nan
        )
        zoomMax = GraphPoint3D(
            x: limitRange(zoomMaxX, isLog: descriptor.logX),
            y: limitRange(zoomMaxY, isLog: descriptor.logY),
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
