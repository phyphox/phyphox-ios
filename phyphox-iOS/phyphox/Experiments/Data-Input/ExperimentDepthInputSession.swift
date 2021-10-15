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
    
    var timeReference: ExperimentTimeReference?
    var zBuffer: DataBuffer?
    var tBuffer: DataBuffer?

    var session = ARSession()
    var smooth: Bool = true
    
    var delegate: DepthGUIDelegate?
    
    var measuring = false
    
    private var queue: DispatchQueue?
    
    override init() {
        super.init()
        session.delegate = self
    }
    
    func runSession() -> CGSize {
        let conf = ARWorldTrackingConfiguration()
        if smooth && ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            conf.frameSemantics = .smoothedSceneDepth
        } else {
            conf.frameSemantics = .sceneDepth
        }
        session.run(conf)
        return conf.videoFormat.imageResolution
    }
    
    func stopSession() {
        session.pause()
    }
    
    func start(queue: DispatchQueue) {
        self.queue = queue
        measuring = true
        _ = runSession()
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
        if measuring {
            guard let depthMapRaw = smooth ? (frame.smoothedSceneDepth?.depthMap ?? frame.sceneDepth?.depthMap) : frame.sceneDepth?.depthMap else {
                print("Error: No depth map.")
                return
            }
            guard CVPixelBufferGetPixelFormatType(depthMapRaw) == kCVPixelFormatType_DepthFloat32 else {
                print("Error: Unexpected depth map format")
                return
            }

            let w = CVPixelBufferGetWidth(depthMapRaw)
            let h = CVPixelBufferGetHeight(depthMapRaw)
            
            CVPixelBufferLockBaseAddress(depthMapRaw, .readOnly)
            let depthMap = unsafeBitCast(CVPixelBufferGetBaseAddress(depthMapRaw), to: UnsafeMutablePointer<Float32>.self)
            
            let xp1 = Int(round(Float(w) * x1))
            let xp2 = Int(round(Float(w) * x2))
            let yp1 = Int(round(Float(h) * y1))
            let yp2 = Int(round(Float(h) * y2))
            let xi1 = max(min(xp1, xp2, w), 0)
            let xi2 = min(max(xp1, xp2, 0), w)
            let yi1 = max(min(yp1, yp2, h), 0)
            let yi2 = min(max(yp1, yp2, 0), h)
            
            var z: Double
            switch mode {
            case .average:
                z = 0.0
            case .closest:
                z = Double.infinity
            }
            for x in xi1...xi2 {
                for y in yi1...yi2 {
                    let zi = Double(depthMap[x + y*w])
                    switch mode {
                    case .average:
                        z += zi
                    case .closest:
                        z = min(z, zi)
                    }
                }
            }
            if mode == .average {
                z /= Double((xi2-xi1+1)*(yi2-yi1+1))
            }
            
            CVPixelBufferUnlockBaseAddress(depthMapRaw, .readOnly)
            
            dataIn(z: z, time: frame.timestamp)
        }
        
        delegate?.updateFrame(frame: frame)
    }
    
    public func attachDelegate(delegate: DepthGUIDelegate) {
        self.delegate = delegate
        let res = runSession()
        delegate.updateResolution(resolution: res)
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

