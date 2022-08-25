//
//  ExperimentDepthInput.swift
//  phyphox
//
//  Created by Sebastian Staacks on 12.10.21.
//  Copyright © 2021 RWTH Aachen. All rights reserved.
//

import Foundation
import ARKit

@available(iOS 14.0, *)
final class ExperimentDepthInputSession: NSObject, ARSessionDelegate, DepthGUISelectionDelegate {

    var mode: ExperimentDepthInput.DepthExtractionMode = .closest
    var x1: Float = 0.4
    var x2: Float = 0.6
    var y1: Float = 0.4
    var y2: Float = 0.6
    
    var running = false
    
    var frontCamera: Bool {
        didSet {
            if running {
                do {
                    stopSession()
                    _ = try runSession()
                } catch {
                    print("No camera available while switching cameras.")
                }
            }
        }
    }
    
    var timeReference: ExperimentTimeReference?
    var zBuffer: DataBuffer?
    var tBuffer: DataBuffer?

    var arSession = ARSession()
    var smooth: Bool = true
    
    var delegate: DepthGUIDelegate?
    
    var measuring = false
    
    private var queue: DispatchQueue?
    
    override init() {
        frontCamera = false
        super.init()
        arSession.delegate = self
    }
    
    func ensureAvailableCamera() throws {
        do {
            try ExperimentDepthInput.verifySensorAvailibility(cameraOrientation: frontCamera ? .front : .back)
        } catch {
            print("\(frontCamera ? "front" : "back") camera not available. Switching.")
            self.frontCamera = !frontCamera
            try ExperimentDepthInput.verifySensorAvailibility(cameraOrientation: frontCamera ? .front : .back)
        }
    }

    func runSession() throws -> CGSize {
        if running {
            return arSession.configuration?.videoFormat.imageResolution ?? CGSize(width: 0,height: 0)
        }
        
        try ensureAvailableCamera()
        
        print("Starting depth session with \(frontCamera ? "front" : "back") camera")
        let conf: ARConfiguration
        if frontCamera {
            conf = ARFaceTrackingConfiguration()
        } else {
            conf = ARWorldTrackingConfiguration()
            if smooth && ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
                conf.frameSemantics = .smoothedSceneDepth
            } else {
                conf.frameSemantics = .sceneDepth
            }
        }
        arSession.run(conf)
        running = true
        return conf.videoFormat.imageResolution
    }
    
    func stopSession() {
        running = false
        arSession.pause()
    }
    
    func start(queue: DispatchQueue) throws {
        self.queue = queue
        measuring = true
        _ = try runSession()
    }
    
    func stop() {
        measuring = false
        if delegate == nil {
            stopSession()
        }
    }
    
    func clear() {
        
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        delegate?.updateFrame(frame: frame)
        if measuring {
            guard let depthMapRaw = (smooth ? (frame.smoothedSceneDepth?.depthMap ?? frame.sceneDepth?.depthMap) : frame.sceneDepth?.depthMap) ?? frame.capturedDepthData?.depthDataMap else {
                if !frontCamera {
                    print("Error: No depth map.")
                }
                return
            }
            guard CVPixelBufferGetPixelFormatType(depthMapRaw) == kCVPixelFormatType_DepthFloat32 else {
                print("Error: Unexpected depth map format \(CVPixelBufferGetPixelFormatType(depthMapRaw))")
                return
            }
            let confidenceMapRaw = smooth ? (frame.smoothedSceneDepth?.confidenceMap ?? frame.sceneDepth?.confidenceMap) : frame.sceneDepth?.confidenceMap
            if let confidenceMapRaw = confidenceMapRaw {
                guard CVPixelBufferGetPixelFormatType(confidenceMapRaw) == kCVPixelFormatType_OneComponent8 else {
                    print("Error: Unexpected confidence map format \(CVPixelBufferGetPixelFormatType(confidenceMapRaw))")
                    return
                }
            }
            
            let w = CVPixelBufferGetWidth(depthMapRaw)
            let h = CVPixelBufferGetHeight(depthMapRaw)
            
            CVPixelBufferLockBaseAddress(depthMapRaw, .readOnly)
            let depthMap = unsafeBitCast(CVPixelBufferGetBaseAddress(depthMapRaw), to: UnsafeMutablePointer<Float32>.self)
            
            let confidenceMap: UnsafeMutablePointer<UInt8>?
            if let confidenceMapRaw = confidenceMapRaw {
                CVPixelBufferLockBaseAddress(confidenceMapRaw, .readOnly)
                confidenceMap = unsafeBitCast(CVPixelBufferGetBaseAddress(confidenceMapRaw), to: UnsafeMutablePointer<UInt8>.self)
            } else {
                confidenceMap = nil
            }
            frameIn(depthMap: depthMap, confidenceMap: confidenceMap, w: w, h: h, t: frame.timestamp)
            
            CVPixelBufferUnlockBaseAddress(depthMapRaw, .readOnly)
            if let confidenceMapRaw = confidenceMapRaw {
                CVPixelBufferUnlockBaseAddress(confidenceMapRaw, .readOnly)
            }
        }
    }
    
    func frameIn(depthMap: UnsafeMutablePointer<Float32>, confidenceMap: UnsafeMutablePointer<UInt8>?, w: Int, h: Int, t: TimeInterval) {

        let xp1 = Int(round(Float(w) * x1))
        let xp2 = Int(round(Float(w) * x2))
        let yp1 = Int(round(Float(h) * y1))
        let yp2 = Int(round(Float(h) * y2))
        let xi1 = max(min(xp1, xp2, w), 0)
        let xi2 = min(max(xp1, xp2, 0), w)
        let yi1 = max(min(yp1, yp2, h), 0)
        let yi2 = min(max(yp1, yp2, 0), h)
        
        var z: Double
        var sum = 0.0
        switch mode {
        case .average, .weighted:
            z = 0.0
        case .closest:
            z = Double.infinity
        }
        for x in xi1...xi2 {
            for y in yi1...yi2 {
                let zi = Double(depthMap[x + y*w])
                if !zi.isFinite {
                    continue
                }
                let confidence: UInt8
                if let confidenceMap = confidenceMap {
                    confidence = confidenceMap[x + y*w]
                    if confidence <= ARConfidenceLevel.low.rawValue {
                        continue
                    }
                } else {
                    confidence = 1
                }
                switch mode {
                case .average:
                    z += zi
                    sum += 1
                case .closest:
                    z = min(z, zi)
                case .weighted:
                    z += zi * Double(confidence)
                    sum += Double(confidence)
                }
            }
        }
        if mode == .average || mode == .weighted {
            if sum > 0 {
                z /= sum
            } else {
                z = Double.nan
            }
        }
        if z.isInfinite {
            z = Double.nan
        }
        
        dataIn(z: z, time: t)
    }
    
    public func attachDelegate(delegate: DepthGUIDelegate) {
        self.delegate = delegate
        if let res = try? runSession() {
            delegate.updateResolution(resolution: res)
        }
    }
    
    private func writeToBuffers(z: Double, t: TimeInterval) {
        if let zBuffer = zBuffer {
            zBuffer.append(z)
        }
        
        if let tBuffer = tBuffer {
            tBuffer.append(t)
        }
    }
    
    private func dataIn(z: Double, time: TimeInterval) {
        guard let timeReference = timeReference else {
            print("Error: time reference not set")
            return
        }
        let t = timeReference.getExperimentTimeFromEvent(eventTime: time)
        if t >= timeReference.timeMappings.last?.experimentTime ?? 0.0 {
            queue?.async {
                autoreleasepool(invoking: {
                    self.writeToBuffers(z: z, t: t)
                })
            }
        }
    }
}

