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
final class ExperimentCameraInputSession: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, CameraGUISelectionDelegate, ObservableObject {

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
    
    private var queue: DispatchQueue? = DispatchQueue.global(qos: .userInteractive)
    private var queueOutput: DispatchQueue? = DispatchQueue.global(qos: .userInteractive)
    // Communicate with the session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    @Published var cameraSession = AVCaptureSession()
   
    var screenRect: CGRect! = nil // For view dimensions
    
    
    var isSessionRunning = false
//    12
    var isConfigured = false
//    13
    //var setupResult: SessionSetupResult = .success
    
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    //    MARK: Alert properties
        public var alertError: AlertError = AlertError()
    
    
    @Published public var shouldShowAlertView = false
//    3.
    @Published public var shouldShowSpinner = false
//    4.
    @Published public var willCapturePhoto = false
//    5.
    @Published public var isCameraButtonDisabled = true
//    6.
    @Published public var isCameraUnavailable = true
    
    
    override init(){
        frontCamera = false
    }
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            // Process pixel buffer bytes here
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        
        
        // Convert the image buffer to a CIImage
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
            
        // Convert the CIImage to a UIImage
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        
        let width = cgImage?.width
        let height = cgImage?.height
        
        let uiImage = UIImage(cgImage: cgImage!)
        
        // Example: Print a message in a background queue
        queueOutput?.async {
           
        }
    }
    

    func runSession(){
        // get camera device
        guard let videoDevice = AVCaptureDevice.default(for: .video) else { return }
        
        // plug camera device into device input which talkes with capture session via AVCaptureConnection
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        
        cameraSession.sessionPreset = .high
        if let existingInputs = cameraSession.inputs as? [AVCaptureInput] {
            for input in existingInputs {
                cameraSession.removeInput(input)
            }
        }
        guard cameraSession.canAddInput(videoDeviceInput) else { return }
        cameraSession.addInput(videoDeviceInput)
        
        // setup output, add output to our capture session
        let captureOutput = AVCaptureVideoDataOutput()
        captureOutput.alwaysDiscardsLateVideoFrames = true
        captureOutput.setSampleBufferDelegate(self, queue: queue)
        cameraSession.addOutput(captureOutput)
        
        self.delegate?.updateFrame(captureSession: self.cameraSession)
        
        queue?.async {
            print("runSession Queue")
            if (self.cameraSession.isRunning == false) {
                self.cameraSession.startRunning()
            }
        }
    }
    
    func stopSession() {
        running = false
        if (self.cameraSession.isRunning == true) {
            self.cameraSession.stopRunning()
        }
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

