//
//  MetalRenderer.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 24.11.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation
import MetalKit
import AVFoundation
import Accelerate

@available(iOS 14.0, *)
class AnalyzingRenderer {
    
    var cameraModelOwner: CameraModelOwner? = nil
    var metalDevice: MTLDevice!
    var metalCommandQueue: MTLCommandQueue!
    var imagePlaneVertexBuffer: MTLBuffer!
    
    var defaultVideoDevice: AVCaptureDevice? = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    
    // An object that defines the Metal shaders that render the camera image.
    var pipelineState: MTLRenderPipelineState!
    
    let inFlightSemaphore: DispatchSemaphore
            
    var measuring: Bool = false
   
    var timeReference: ExperimentTimeReference?
    var cameraBuffers: ExperimentCameraBuffers?
    
    private var queue: DispatchQueue?
    
    var timeStampOfFrame: TimeInterval = TimeInterval()
        
    var analysingModules : [AnalysingModule] = []
        
    init(inFlightSemaphore: DispatchSemaphore) {
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.metalDevice = metalDevice
        }
        self.inFlightSemaphore = inFlightSemaphore
             
        initializeMetal()
    }
    
    func initializeCameraBuffer(cameraBuffers: ExperimentCameraBuffers?){
        self.cameraBuffers = cameraBuffers
        
        AnalysingModule.initialize(metalDevice: metalDevice)
        
        
        if(cameraBuffers?.luminanceBuffer != nil){
            analysingModules.append(LuminanceAnalyser(result: cameraBuffers?.luminanceBuffer))
        }
        
        if(cameraBuffers?.lumaBuffer != nil){
            analysingModules.append(LumaAnalyser(result: cameraBuffers?.lumaBuffer))
        }
        
        if(cameraBuffers?.hueBuffer != nil){
            analysingModules.append(HSVAnalyser(result: cameraBuffers?.hueBuffer, mode: .Hue ))
        }
        
        if(cameraBuffers?.saturationBuffer != nil){
            analysingModules.append(HSVAnalyser(result: cameraBuffers?.saturationBuffer, mode: .Saturation))
        }
        
        if(cameraBuffers?.valueBuffer != nil) {
            analysingModules.append(HSVAnalyser(result: cameraBuffers?.valueBuffer, mode: .Value))
        }
        
        if(cameraBuffers?.thresholdBuffer != nil){
           // analysingModules.append(HSVAnalyser(result: cameraBuffers?.thresholdBuffer))
        }
        
        for analysingModule in analysingModules {
            analysingModule.loadMetal()
        }
       
    }
        
    func updateFrame(time: TimeInterval, cameraImageTextureY: CVMetalTexture, cameraImageTextureCbCr: CVMetalTexture) {
                
        if measuring {
            timeStampOfFrame = time
        }
        
        update(cameraImageTextureY: cameraImageTextureY, cameraImageTextureCbCr: cameraImageTextureCbCr)
        
    }
    
    func start(queue: DispatchQueue) throws {
        self.queue = queue
    }

    
    private func dataIn() {
     
        guard let timeReference = timeReference else {
            print("Error: time reference not set")
            return
        }
        
        let t = timeReference.getExperimentTimeFromEvent(eventTime: timeStampOfFrame)
        
        if t >= timeReference.timeMappings.last?.experimentTime ?? 0.0 {
            
            if let tBuffer = cameraBuffers?.tBuffer {
                tBuffer.append(t)
            }
            
            for analysingModule in analysingModules {
                analysingModule.writeToBuffers()
            }
        }
    }

    
    func initializeMetal(){
        // Create the command queue for one frame of rendering work.
        metalCommandQueue = metalDevice.makeCommandQueue()
    }
    
    
    func update(cameraImageTextureY: CVMetalTexture, cameraImageTextureCbCr: CVMetalTexture) {
        
        guard let selectionArea = cameraModelOwner?.cameraModel?.selectionArea else {
            return
        }
        
        // Wait to ensure only kMaxBuffersInFlight are getting proccessed by any stage in the Metal
        // pipeline (App, Metal, Drivers, GPU, etc).
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        // Create a new command buffer for each renderpass to the current drawable.
        if let commandBuffer = metalCommandQueue.makeCommandBuffer() {
            commandBuffer.label = "AnalyzeCommand"
            
            
            // Add completion hander which signal _inFlightSemaphore when Metal and the GPU has fully
            // finished proccssing the commands we're encoding this frame.  This indicates when the
            // dynamic buffers, that we're writing to this frame, will no longer be needed by Metal
            // and the GPU.
            commandBuffer.addCompletedHandler { [weak self] commandBuffer in
                if let strongSelf = self {
                    strongSelf.inFlightSemaphore.signal()
                }
            }
            
        }
        
        if self.measuring {
            
            if let analysisCommandBuffer = metalCommandQueue.makeCommandBuffer() {
                
                let startTime = Date()
                
                analysisCommandBuffer.addCompletedHandler { commandBuffer in
                    let endTime = Date()
                    let executionTime = endTime.timeIntervalSince(startTime)
                    print("executionTime : \(executionTime)")
                    
                    self.dataIn()
                    
                }
                
                for analysingModule in analysingModules {
                    
                    guard let textureY = CVMetalTextureGetTexture(cameraImageTextureY) else { return }
                    guard let textureCbCr = CVMetalTextureGetTexture(cameraImageTextureCbCr) else { return }
                    
                    analysingModule.update(selectionArea: SelectionState(x1: Float(selectionArea.minX), x2: Float(selectionArea.maxX), y1: Float(selectionArea.minY), y2: Float(selectionArea.maxY), editable: false),
                                           metalCommandBuffer: analysisCommandBuffer,
                                           cameraImageTextureY: textureY,
                                           cameraImageTextureCbCr: textureCbCr)
                }
                
                analysisCommandBuffer.commit()
                analysisCommandBuffer.waitUntilCompleted()
               
            }
            
        }
        
    }
   
}

extension CGImagePropertyOrientation {
    init(interfaceOrientation: UIInterfaceOrientation) {
        switch interfaceOrientation {
        case .portrait:
            self = .up
        case .portraitUpsideDown:
            self = .down
        case .landscapeLeft:
            self = .left
        case .landscapeRight:
            self = .right
        default:
            self = .up
        }
    }
}
