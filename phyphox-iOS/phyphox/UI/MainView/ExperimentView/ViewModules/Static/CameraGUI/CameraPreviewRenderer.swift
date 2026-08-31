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
    
    var cameraModelOwner: CameraModelOwner?
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
    
    let descriptor: CameraViewDescriptor

    // An object that defines the Metal shaders that render the camera image.
    var pipelineState: MTLRenderPipelineState!
    
    var drawableSize: CGSize = CGSize()
    var drawableSizeDidChange: Bool = false
    var cameraOrientation: AVCaptureDevice.Position? = nil
    var interfaceOrientation: UIInterfaceOrientation = .unknown
    
    var isOverlayEditable: Bool = false
    
    init(metalDevice: MTLDevice, renderDestination: MTKView, descriptor: CameraViewDescriptor) {
        self.metalDevice = metalDevice
        self.renderDestination = renderDestination
        self.descriptor = descriptor
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
        let vertexFunction = defaultLibrary.makeFunction(name: "cameraGUIvertexTransform")!
        let fragmentFunction = defaultLibrary.makeFunction(name: "cameraGUIfragmentShader")!
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
        drawableSize = size
        drawableSizeDidChange = true
    }
    
    func draw(in view: MTKView) {
        if let strongSemaphore = self.inFlightSemaphore {
            _ = strongSemaphore.wait(timeout: DispatchTime.distantFuture)
           
            guard let commandBuffer = metalCommandQueue.makeCommandBuffer() else {
                strongSemaphore.signal()
                return
            }
            
            commandBuffer.label = "CameraPreviewCommand"
            
            commandBuffer.addCompletedHandler { [weak self] commandBuffer in
                if let strongSemaphore = self?.inFlightSemaphore {
                    strongSemaphore.signal()
                }
            }
            
            let success = update(commandBuffer: commandBuffer, viewportSize: view.frame)
            
            if !success {
                // If update failed, we must not wait for GPU
                // and also signal the semaphore manually
                strongSemaphore.signal()
            }else {
                if commandBuffer.status == .notEnqueued {
                    print("WARNING: Command buffer was never committed. Committing manually.")
                    commandBuffer.commit()
                }
            }
        }
    }
        
    func update(commandBuffer: MTLCommandBuffer, viewportSize: CGRect) -> Bool {
        updateAppState()
        
        guard let renderPassDescriptor = renderDestination.currentRenderPassDescriptor,
              let currentDrawable = renderDestination.currentDrawable else {
            return false
        }
        
        //Resolve the (weakly held) camera model before creating the encoder. If both were checked
        //in one guard and only the model were nil - which happens while leaving the experiment, as
        //the model is torn down but the MTKView fires one last draw - the encoder would already be
        //created and then released without endEncoding(), which aborts with a Metal assertion.
        guard let cameraModel = cameraModelOwner?.cameraModel else {
            return false
        }

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return false
        }
        // Set a label to identify this render pass in a captured Metal frame.
        renderEncoder.label = "CameraGUIPreview"
        // Push a debug group that enables you to identify this render pass in a Metal frame capture.
        renderEncoder.pushDebugGroup("CameraPass")
        // Set render command encoder state.
        renderEncoder.setCullMode(.none)
        renderEncoder.setRenderPipelineState(pipelineState)
        
        
        let selectionArea = cameraModel.selectionArea
        let selectionState = SelectionState(x1: Float(selectionArea.minX), x2: Float(selectionArea.maxX), y1: Float(selectionArea.minY), y2: Float(selectionArea.maxY), editable: isOverlayEditable)
        let p1 = CGPoint(x: CGFloat(selectionState.x1), y: CGFloat(selectionState.y1)).applying(displayToCameraTransform.inverted())
        let p2 = CGPoint(x: CGFloat(selectionState.x2), y: CGFloat(selectionState.y2)).applying(displayToCameraTransform.inverted())
        
        //Scale to resolution of the metal view drawable. Important: This is not viewportSize, which is in screen coordinates, drawableSize which is in pixels! Also, the camera resolution does not play a role here as it is rendered to a texture which is simply accessed by the shader via normalized texture coordinates.
        var scaledSelectionState = SelectionState(x1: Float(min(p1.x, p2.x)*drawableSize.width), x2: Float(max(p1.x, p2.x)*drawableSize.width), y1: Float(min(p1.y, p2.y)*drawableSize.height), y2: Float(max(p1.y, p2.y)*drawableSize.height), editable: selectionState.editable)
        
        renderEncoder.setFragmentBytes(&scaledSelectionState, length: MemoryLayout<SelectionState>.stride, index: 2)
        
        var shaderColorModifier = ShaderColorModifier(
            grayscale: descriptor.grayscale,
            overexposureColor: vector_float3(
                Float(descriptor.markOverexposure?.red ?? .nan),
                Float(descriptor.markOverexposure?.green ?? .nan),
                Float(descriptor.markOverexposure?.blue ?? .nan)
            ), underexposureColor: vector_float3(
                Float(descriptor.markUnderexposure?.red ?? .nan),
                Float(descriptor.markUnderexposure?.green ?? .nan),
                Float(descriptor.markUnderexposure?.blue ?? .nan)
            ))
        renderEncoder.setFragmentBytes(&shaderColorModifier, length: MemoryLayout<ShaderColorModifier>.stride, index: 3)
        
        // Setup plane vertex buffers.
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: 1)
        
        guard let cameraTextureProvider = cameraTextureProvider else {
            renderEncoder.endEncoding()
            return false
        }
        
        var aborted = false
        cameraTextureProvider.safeTextureAccess {
            guard let cameraImageTextureY = cameraTextureProvider.cameraImageTextureY,
                  let cameraImageTextureCbCr = cameraTextureProvider.cameraImageTextureCbCr
            else {
                renderEncoder.endEncoding()
                aborted = true
                return
            }
            renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(cameraImageTextureY), index: 0)
            renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(cameraImageTextureCbCr), index: 1)
        }
        if aborted {
            return false
        }
        
        // Draw final quad to display
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.popDebugGroup()
        
        // Finish encoding commands.
        renderEncoder.endEncoding()
        commandBuffer.present(currentDrawable)
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return true
    }
   
    // Updates any app state.
    func updateAppState() {
        // Update the destination-rendering vertex info if the size of the screen, the interface
        // orientation or the camera changed.
        if drawableSizeDidChange || cameraOrientation != cameraModelOwner?.cameraModel?.cameraSettingsModel.cameraPosition || interfaceOrientation != currentInterfaceOrientation() {
            drawableSizeDidChange = false
            updateImagePlane()
        }
    }

    // Sets up vertex data (source and destination rectangles) rendering.
    func updateImagePlane() {
        cameraOrientation = cameraModelOwner?.cameraModel?.cameraSettingsModel.cameraPosition
        interfaceOrientation = currentInterfaceOrientation()
        displayToCameraTransform = transformForInterfaceOrientation(interfaceOrientation)
        let cameraSpecificTransform = if cameraOrientation == .front {
            //Image of fron facing camera needs to be mirrored for intuitive use
            displayToCameraTransform.concatenating(CGAffineTransform(1.0, 0.0, 0.0, -1.0, 0.0, 1.0))
        } else {
            displayToCameraTransform
        }
        let vertexData = imagePlaneVertexBuffer.contents().assumingMemoryBound(to: Float.self)
        for index in 0...3 {
            let textureCoordIndex = 4 * index + 2
            let textureCoord = CGPoint(x: CGFloat(kImagePlaneVertexData[textureCoordIndex]), y: CGFloat(kImagePlaneVertexData[textureCoordIndex + 1]))
            let transformedCoord = textureCoord.applying(cameraSpecificTransform)
            vertexData[textureCoordIndex] = Float(transformedCoord.x)
            vertexData[textureCoordIndex + 1] = Float(transformedCoord.y)
        }
    }
    
    //The interface orientation of the window this view is shown in. This must be the same source
    //that the layout code uses to pick the aspect ratio of the metal view: the transform below
    //and the layout have to agree or the preview gets distorted. In particular, the physical
    //device orientation (UIDevice.current.orientation) is not suitable, as it reports
    //faceUp/faceDown when the device is tilted flat - typical when pointing the camera at a
    //spectroscopy setup - while the interface keeps its last orientation.
    func currentInterfaceOrientation() -> UIInterfaceOrientation {
        return renderDestination.window?.windowScene?.interfaceOrientation
            ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.windowScene?.interfaceOrientation
            ?? .portrait
    }

    func transformForInterfaceOrientation(_ orientation: UIInterfaceOrientation) -> CGAffineTransform {
        switch orientation {
        case .portrait:
            return CGAffineTransform(a: 0.0, b: -1.0, c: 1.0, d: 0.0, tx: 0.0, ty: 1.0)

        case .landscapeRight:
            return CGAffineTransform.identity

        case .landscapeLeft:
            return CGAffineTransform(a: -1.0, b: 0.0, c: 0.0, d: -1.0, tx: 1.0, ty: 1.0)

        case .portraitUpsideDown:
            return CGAffineTransform(a: 0.0, b: 1.0, c: -1.0, d: 0.0, tx: 1.0, ty: 1.0)

        default:
            return CGAffineTransform(a: 0.0, b: -1.0, c: 1.0, d: 0.0, tx: 0.0, ty: 1.0)
        }

    }
   
}

