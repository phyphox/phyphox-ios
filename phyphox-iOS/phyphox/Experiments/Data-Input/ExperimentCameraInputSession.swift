//
//  ExperimentCameraInputSession.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 07.09.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation
import AVFoundation

@available(iOS 14.0, *)
final class ExperimentCameraInputSession: CameraGUISelectionDelegate {


    var x1: Float = 0.4
    var x2: Float = 0.6
    var y1: Float = 0.4
    var y2: Float = 0.6
    
    var running = false
    
    var frontCamera: Bool
    
    var timeReference: ExperimentTimeReference?
    var zBuffer: DataBuffer?
    var tBuffer: DataBuffer?

    var smooth: Bool = true
    
    var delegate: CameraGUIDelegate?
    
    var measuring = false
    
    private var queue: DispatchQueue?
    
    var cameraSession = AVCaptureSession()
   
    var screenRect: CGRect! = nil // For view dimensions
    
    init(){
        frontCamera = false
    }
    

    func runSession(){
        
        
        guard let videoDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: AVMediaType.video, position:  .back) else { return }
        
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        
        guard cameraSession.canAddInput(videoDeviceInput) else { return }
        cameraSession.addInput(videoDeviceInput)
        
        cameraSession.startRunning()
        
        delegate?.updateFrame(captureSession: cameraSession)
    }
    
    func stopSession() {
        running = false
    }
    
    func start(queue: DispatchQueue) throws {
        self.queue = queue
        measuring = true
    }
    
    func stop() {
        measuring = false
    }
    
    func clear() {
        
    }
    
    func session() {

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
        
    }
    
    public func attachDelegate(delegate: CameraGUIDelegate) {
        self.delegate = delegate
        runSession()
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

