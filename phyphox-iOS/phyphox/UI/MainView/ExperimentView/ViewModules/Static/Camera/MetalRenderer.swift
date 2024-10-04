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

@available(iOS 13.0, *)
class MetalRenderer: NSObject,  MTKViewDelegate{
    
    struct SelectionStruct {
        var x1, x2, y1, y2: Float
        var editable: Bool
        
        var padding: (UInt8, UInt8, UInt8) = (0, 0, 0)
    }
    
    var metalDevice: MTLDevice!
    var metalCommandQueue: MTLCommandQueue!
    var imagePlaneVertexBuffer: MTLBuffer!
    
    var defaultVideoDevice: AVCaptureDevice? = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    
    // The current viewport size.
    var viewportSize: CGSize = CGSize()
    
    // Flag for viewport size changes.
    var viewportSizeDidChange: Bool = false
    
    // An object that defines the Metal shaders that render the camera image.
    var pipelineState: MTLRenderPipelineState!

    // Captured image texture cache.
    var cameraImageTextureCache: CVMetalTextureCache!
    
    let inFlightSemaphore = DispatchSemaphore(value: kMaxBuffersInFlight)
    
    var selectionState = SelectionStruct(x1: 0.4, x2: 0.6, y1: 0.4, y2: 0.6, editable: false)
    
    // Textures used to transfer the current camera image to the GPU for rendering.
    var cameraImageTextureY: CVMetalTexture?
    var cameraImageTextureCbCr: CVMetalTexture?
    
    var cvImageBuffer : CVImageBuffer?
    
    var measuring: Bool = false
   
    var timeReference: ExperimentTimeReference?
    var cameraBuffers: ExperimentCameraBuffers?
    
    private var queue: DispatchQueue?
    
    var timeStampOfFrame: TimeInterval = TimeInterval()
    
    var cameraPreviewRenderer: CameraPreviewRenderer
    
    var analysingModules : [AnalysingModule] = []
    
    init(renderer: MTKView) {

        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.metalDevice = metalDevice
        }
        
        cameraPreviewRenderer = CameraPreviewRenderer(metalDevice: metalDevice, renderer: renderer)
        
        super.init()
     
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
    
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        drawRectResized(size: size)
    }
    
    func draw(in view: MTKView) {
        update()
    }
    
    // Schedule a draw to happen at a new size.
    func drawRectResized(size: CGSize) {
        viewportSize = size
        viewportSizeDidChange = true
    }
    
    func deviceChanged(){
        viewportSizeDidChange = true
    }
    
    func updateFrame(imageBuffer: CVImageBuffer!, selectionState: SelectionStruct, time: TimeInterval) {
        
        if imageBuffer != nil {
            self.cvImageBuffer = imageBuffer
        }
        
        self.selectionState = selectionState
        
        if measuring {
            timeStampOfFrame = time
        }
        
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
        
        cameraPreviewRenderer.loadMetal()
        
        // Create camera image texture cache.
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, metalDevice, nil, &textureCache)
        cameraImageTextureCache = textureCache
        
        // Create the command queue for one frame of rendering work.
        metalCommandQueue = metalDevice.makeCommandQueue()
        
    }
    
    
    func update() {
        
        // Wait to ensure only kMaxBuffersInFlight are getting proccessed by any stage in the Metal
        // pipeline (App, Metal, Drivers, GPU, etc).
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        // Create a new command buffer for each renderpass to the current drawable.
        if let commandBuffer = metalCommandQueue.makeCommandBuffer() {
            commandBuffer.label = "MyCommand"
            
            
            // Add completion hander which signal _inFlightSemaphore when Metal and the GPU has fully
            // finished proccssing the commands we're encoding this frame.  This indicates when the
            // dynamic buffers, that we're writing to this frame, will no longer be needed by Metal
            // and the GPU.
            commandBuffer.addCompletedHandler { [weak self] commandBuffer in
                if let strongSelf = self {
                    strongSelf.inFlightSemaphore.signal()
                }
            }
            
            updateAppState()
            
            cameraPreviewRenderer.update(commandBuffer: commandBuffer, 
                                         selectionState: selectionState,
                                         cameraImageTextureY: cameraImageTextureY,
                                         cameraImageTextureCbCr: cameraImageTextureCbCr,
                                         viewportSize: viewportSize)
            
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
                    
                    guard let cameraImageY = cameraImageTextureY, let cameraImageCbCr = cameraImageTextureCbCr else {
                        return
                    }
                    
                    guard let textureY = CVMetalTextureGetTexture(cameraImageY) else { return }
                    guard let textureCbCr = CVMetalTextureGetTexture(cameraImageCbCr) else { return }
                    
                    analysingModule.update(selectionArea: getSelectionState(),
                                           metalCommandBuffer: analysisCommandBuffer,
                                           cameraImageTextureY: textureY,
                                           cameraImageTextureCbCr: textureCbCr)
                }
                
                analysisCommandBuffer.commit()
                analysisCommandBuffer.waitUntilCompleted()
               
            }
            
        }
        
    }
   
    func getSelectionState() -> SelectionStruct{
        let p1 = CGPoint(x: CGFloat(selectionState.x1), y: CGFloat(selectionState.y1))
            .applying(cameraPreviewRenderer.displayToCameraTransform.inverted())
        let p2 = CGPoint(
            x: CGFloat(selectionState.x2), y: CGFloat(selectionState.y2)
        ).applying(cameraPreviewRenderer.displayToCameraTransform.inverted())
        
        // TODO: hard coded resolution size need to be refactored
        return SelectionStruct(x1: Float(min(p1.x, p2.x)*480),
                               x2: Float(max(p1.x, p2.x)*480),
                               y1: Float(min(p1.y, p2.y)*360),
                               y2: Float(max(p1.y, p2.y)*360),
                               editable: selectionState.editable)
    }

   
    // Updates any app state.
    func updateAppState() {
        
        guard let currentFrame = self.cvImageBuffer else {
            return
        }
        
        // Prepare the current frame's camera image for transfer to the GPU.
        updateCameraImageTextures(frame: currentFrame)
        
        // Update the destination-rendering vertex info if the size of the screen changed.
        if viewportSizeDidChange {
            viewportSizeDidChange = false
            cameraPreviewRenderer.updateImagePlane(frame: currentFrame, defaultVideoDevice: defaultVideoDevice)
        }
    }
    
    // Creates two textures (Y and CbCr) to transfer the current frame's camera image to the GPU for rendering.
    func updateCameraImageTextures(frame: CVImageBuffer) {
        if CVPixelBufferGetPlaneCount(frame) < 2 {
            print("updateCameraImageTextures less than 2")
            return
        }
        cameraImageTextureY = createTexture(fromPixelBuffer: frame, pixelFormat: .r8Unorm, planeIndex: 0)
        cameraImageTextureCbCr = createTexture(fromPixelBuffer: frame, pixelFormat: .rg8Unorm, planeIndex: 1)
    }
    
    // Creates a Metal texture with the argument pixel format from a CVPixelBuffer at the argument plane index.
    func createTexture(fromPixelBuffer pixelBuffer: CVImageBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
        
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex) // for example 480  //240
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex) // for example 360 //180
        
        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, cameraImageTextureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)
        
        if status != kCVReturnSuccess {
            texture = nil
        }
        
        return texture
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
