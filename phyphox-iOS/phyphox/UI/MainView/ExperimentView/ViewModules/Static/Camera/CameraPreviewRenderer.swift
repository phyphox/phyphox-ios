//
//  CameraPreviewRenderer.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 14.09.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation
import MetalKit
import AVFoundation


@available(iOS 14.0, *)
class CameraPreviewRenderer: NSObject, MTKViewDelegate {
    
    var cameraModelState: CameraModelState?
    var cameraTextureProvider: CameraMetalTextureProvider? {
        didSet {
            self.inFlightSemaphore = cameraTextureProvider?.inFlightSemaphore
        }
    }
    
    var inFlightSemaphore: DispatchSemaphore?
    
    var metalDevice: MTLDevice
    var renderDestination: MTKView
    var metalCommandQueue: MTLCommandQueue!
    var imagePlaneVertexBuffer: MTLBuffer!
    var cameraImageTextureCache: CVMetalTextureCache!
    var displayToCameraTransform: CGAffineTransform = .identity

    // An object that defines the Metal shaders that render the camera image.
    var pipelineState: MTLRenderPipelineState!
    
    init(metalDevice: MTLDevice, renderDestination: MTKView) {
        self.metalDevice = metalDevice
        self.renderDestination = renderDestination
        metalCommandQueue = metalDevice.makeCommandQueue()
    }
 
    
    func loadMetal(){
                
        // Set the default formats needed to render.
        renderDestination.colorPixelFormat = .bgra8Unorm
        renderDestination.sampleCount = 1
        
        // Create a vertex buffer with our image plane vertex data.
        let imagePlaneVertexDataCount = kImagePlaneVertexData.count * MemoryLayout<Float>.size
        imagePlaneVertexBuffer = metalDevice.makeBuffer(bytes: kImagePlaneVertexData, length: imagePlaneVertexDataCount, options: [])
        imagePlaneVertexBuffer.label = "ImagePlaneVertexBuffer"
        
        // Load all the shader files with a metal file extension in the project.
        let defaultLibrary = metalDevice.makeDefaultLibrary()!
        
        // Create a vertex descriptor for our image plane vertex buffer.
        let imagePlaneVertexDescriptor = MTLVertexDescriptor()
        
        // Positions.
        imagePlaneVertexDescriptor.attributes[0].format = .float2
        imagePlaneVertexDescriptor.attributes[0].offset = 0
        imagePlaneVertexDescriptor.attributes[0].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)
        
        // Texture coordinates.
        imagePlaneVertexDescriptor.attributes[1].format = .float2
        imagePlaneVertexDescriptor.attributes[1].offset = 8
        imagePlaneVertexDescriptor.attributes[1].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)
        
        // Buffer Layout.
        imagePlaneVertexDescriptor.layouts[0].stride = 16
        imagePlaneVertexDescriptor.layouts[0].stepRate = 1
        imagePlaneVertexDescriptor.layouts[0].stepFunction = .perVertex
        
        // Create camera image texture cache.
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, metalDevice, nil, &textureCache)
        cameraImageTextureCache = textureCache
        
        // Define the shaders that will render the camera image on the GPU.
        let vertexFunction = defaultLibrary.makeFunction(name: "vertexTransform")!
        let fragmentFunction = defaultLibrary.makeFunction(name: "fragmentShader")!
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.label = "CameraPreviewRender Pipeline"
        pipelineStateDescriptor.sampleCount = renderDestination.sampleCount
        pipelineStateDescriptor.vertexFunction = vertexFunction
        pipelineStateDescriptor.fragmentFunction = fragmentFunction
        pipelineStateDescriptor.vertexDescriptor = imagePlaneVertexDescriptor
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        
        // Initialize the pipeline.
        do {
            try pipelineState = metalDevice.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        } catch let error {
            print("Failed to create pipeline state, error \(error)")
        }
        
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {

    }
    
    func draw(in view: MTKView) {
        if let strongSemaphore = self.inFlightSemaphore {
            _ = strongSemaphore.wait(timeout: DispatchTime.distantFuture)
            
            if let commandBuffer = metalCommandQueue.makeCommandBuffer() {
                commandBuffer.label = "CameraPreviewCommand"
                
                commandBuffer.addCompletedHandler { [weak self] commandBuffer in
                    if let strongSemaphore = self?.inFlightSemaphore {
                        strongSemaphore.signal()
                    }
                }
                
                update(commandBuffer: commandBuffer, cameraImageTextureY: cameraTextureProvider?.cameraImageTextureY, cameraImageTextureCbCr: cameraTextureProvider?.cameraImageTextureCbCr, viewportSize: view.frame)
            }
        }
    }
    
    func update(commandBuffer: MTLCommandBuffer,
                cameraImageTextureY: CVMetalTexture?, cameraImageTextureCbCr: CVMetalTexture?, viewportSize: CGRect){
        if let renderPassDescriptor = renderDestination.currentRenderPassDescriptor, let currentDrawable = renderDestination.currentDrawable {

            if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor), let cameraModelState = cameraModelState {
                
                // Set a label to identify this render pass in a captured Metal frame.
                renderEncoder.label = "CameraGUIPreview"
                
                guard let cameraImageY = cameraImageTextureY, let cameraImageCbCr = cameraImageTextureCbCr else {
                    renderEncoder.endEncoding()
                    return
                }
                
                // Push a debug group that enables you to identify this render pass in a Metal frame capture.
                renderEncoder.pushDebugGroup("CameraPass")
                
                // Set render command encoder state.
                renderEncoder.setCullMode(.none)
                renderEncoder.setRenderPipelineState(pipelineState)
                
                let p1 = CGPoint(x: CGFloat(cameraModelState.x1), y: CGFloat(cameraModelState.y1)).applying( displayToCameraTransform.inverted())
                let p2 = CGPoint(x: CGFloat(cameraModelState.x2), y: CGFloat(cameraModelState.y2)).applying(displayToCameraTransform.inverted())
                var scaledSelectionState = AnalyzingRenderer.SelectionStruct(x1: Float(min(p1.x, p2.x)*viewportSize.width), x2: Float(max(p1.x, p2.x)*viewportSize.width), y1: Float(min(p1.y, p2.y)*viewportSize.height), y2: Float(max(p1.y, p2.y)*viewportSize.height), editable: cameraModelState.isOverlayEditable)
                renderEncoder.setFragmentBytes(&scaledSelectionState, length: MemoryLayout<AnalyzingRenderer.SelectionStruct>.stride, index: 2)
                
                // Setup plane vertex buffers.
                renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: 0)
                renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: 1)
                
                // Setup textures for the camera fragment shader.
                renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(cameraImageY), index: 0)
                renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(cameraImageCbCr), index: 1)
                
                // Draw final quad to display
                renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                renderEncoder.popDebugGroup()
                
                // Finish encoding commands.
                renderEncoder.endEncoding()
            }
            
            // Schedule a present once the framebuffer is complete using the current drawable.
            commandBuffer.present(currentDrawable)
        }
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        
    }
   
    
    // Sets up vertex data (source and destination rectangles) rendering.
    func updateImagePlane(frame: CVImageBuffer, defaultVideoDevice: AVCaptureDevice?) {
        displayToCameraTransform = transformForDeviceOrientation(defaultVideoDevice: defaultVideoDevice)

        let vertexData = imagePlaneVertexBuffer.contents().assumingMemoryBound(to: Float.self)
        for index in 0...3 {
            let textureCoordIndex = 4 * index + 2
            let textureCoord = CGPoint(x: CGFloat(kImagePlaneVertexData[textureCoordIndex]), y: CGFloat(kImagePlaneVertexData[textureCoordIndex + 1]))
            let transformedCoord = textureCoord.applying(displayToCameraTransform)
            vertexData[textureCoordIndex] = Float(transformedCoord.x)
            vertexData[textureCoordIndex + 1] = Float(transformedCoord.y)
        }
    }
    
    func transformForDeviceOrientation(defaultVideoDevice: AVCaptureDevice?) -> CGAffineTransform {
        let currentOrientation = UIDevice.current.orientation
        let isBackCamera = defaultVideoDevice?.position == .back
        
        let rotate90Anticlockwise = CGAffineTransform(a: 0.0, b: 1.0, c: 1.0, d: 0.0, tx: 0.0, ty: 0.0)
        let rotate90ClockWise = CGAffineTransform(a: 0.0, b: -1.0, c: 1.0, d: 0.0, tx: 0.0, ty: 1.0)
        
        // TODO. Need to handle for all the faceup and facedown cases for all protraits and all landscapes modes.
        // For that we need to recognize landscape and portrait through screen's width and height
        switch currentOrientation {
        case .portrait , .faceUp , .faceDown:
            return isBackCamera ? rotate90ClockWise : rotate90Anticlockwise
          
        case .landscapeLeft:
            return isBackCamera ? CGAffineTransform.identity : rotate90Anticlockwise.concatenating(rotate90ClockWise)

        case .landscapeRight:
            // originally image is flipped for front camera, but applying 90 degree anti clock wise and then 90 degree clockwise works
            return isBackCamera ? rotate90ClockWise.concatenating(rotate90ClockWise) : rotate90Anticlockwise.concatenating(rotate90ClockWise)
            
        case .portraitUpsideDown:
            return isBackCamera ? rotate90ClockWise.concatenating(rotate90ClockWise).concatenating(rotate90ClockWise) : rotate90Anticlockwise.concatenating(rotate90ClockWise).concatenating(rotate90ClockWise)
            
        default:
            return CGAffineTransform.identity
        }
        
    }
   
}

