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
    
    var metalDevice: MTLDevice?
    var metalCommandQueue: MTLCommandQueue!
    var imagePlaneVertexBuffer: MTLBuffer!
    var renderDestination: MTKView
    
    // The current viewport size.
    var viewportSize: CGSize = CGSize()
    
    // Flag for viewport size changes.
    var viewportSizeDidChange: Bool = false
    
    // An object that defines the Metal shaders that render the camera image.
    var pipelineState: MTLRenderPipelineState!
    
    // Captured image texture cache.
    var cameraImageTextureCache: CVMetalTextureCache!
    
    let inFlightSemaphore = DispatchSemaphore(value: kMaxBuffersInFlight)
    
    var displayToCameraTransform: CGAffineTransform = .identity
    var selectionState = SelectionStruct(x1: 0.4, x2: 0.6, y1: 0.4, y2: 0.6, editable: false)
    
    
    // Textures used to transfer the current camera image to the GPU for rendering.
    var cameraImageTextureY: CVMetalTexture?
    var cameraImageTextureCbCr: CVMetalTexture?
    
    var cvImageBuffer : CVImageBuffer?
    
    var measuring: Bool = false
    
    
    var timeReference: ExperimentTimeReference?
    var zBuffer: DataBuffer?
    var tBuffer: DataBuffer?
    
    private var queue: DispatchQueue?
    
    struct SelectionStruct {
        var x1, x2, y1, y2: Float
        var editable: Bool
    }
    
    
    init(parent: CameraMetalView ,renderer: MTKView) {
        
        self.renderDestination = renderer
        
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.metalDevice = metalDevice
        }
        
        super.init()
        
        loadMetal()
        
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
    
    
    func updateFrame(imageBuffer: CVImageBuffer!, selectionState: SelectionStruct, time: TimeInterval) {
       
        if imageBuffer != nil {
           
            self.cvImageBuffer = imageBuffer
        }
        
        self.selectionState = selectionState
        
        if measuring {
            getLuma(time: time)
        }
        
    }
    
    func start(queue: DispatchQueue) throws {
        self.queue = queue
    }
    
    func getLuma(time: Double){
        if let pixelBuffer = self.cvImageBuffer{
            
            var luma = 0
            let luminance = 00
            
            CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
            let lumaBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
            let lumaWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
            let lumaHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
            let lumaRowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
            
            var lData = vImage_Buffer(data: lumaBaseAddress, height: vImagePixelCount(lumaHeight), width: vImagePixelCount(lumaWidth), rowBytes: lumaRowBytes)
            
            
            let chromaBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
            let chromaWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1)
            let chromaHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
            let chromaRowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
            
            var cData = vImage_Buffer(data: chromaBaseAddress, height: vImagePixelCount(chromaHeight), width: vImagePixelCount(chromaWidth), rowBytes: chromaRowBytes)
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
            
            let byteBuffer = UnsafeMutableRawPointer(lumaBaseAddress)
            
            let bufferPointer = byteBuffer?.assumingMemoryBound(to: Pixel_8.self)
            
            
            for y in 0...lData.height {
                for x in 0...lData.width {
                    var l = (bufferPointer?[Int(x)] ?? 0) & 0xFF
                    luma += Int(l)
                    
                }
            }
            
            let xmin = Int(self.selectionState.x1 * Float(lData.width))
            let xmax = Int(self.selectionState.x2 * Float(lData.width))
            let ymin = Int(self.selectionState.y1 * Float(lData.height))
            let ymax = Int(self.selectionState.y2 * Float(lData.height))
            
            
            let analysisArea = (xmax - xmin) * (ymax - ymin)
            
            luma /= analysisArea * 255
            
            dataIn(z: Double(luma), time: time)
            
           
        } else {
            //  If the CVImageBuffer is not a CVPixelBuffer, you may need to perform conversion
            
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
        guard let zBuffer = zBuffer else {
            print("Error: zBuffer not set")
            return
        }
        guard let tBuffer = tBuffer else {
            print("Error: tBuffer not set")
            return
        }
        guard let timeReference = timeReference else {
            print("Error: time reference not set")
            return
        }
        
        let t = timeReference.getExperimentTimeFromEvent(eventTime: time)

        if t >= timeReference.timeMappings.last?.experimentTime ?? 0.0 {
            self.writeToBuffers(z: z, t: t)
        }
    }
    
    func loadMetal(){
       
        // Set the default formats needed to render.
        renderDestination.colorPixelFormat = .bgra8Unorm
        renderDestination.sampleCount = 1
        
        // Create a vertex buffer with our image plane vertex data.
        let imagePlaneVertexDataCount = kImagePlaneVertexData.count * MemoryLayout<Float>.size
        imagePlaneVertexBuffer = metalDevice?.makeBuffer(bytes: kImagePlaneVertexData, length: imagePlaneVertexDataCount, options: [])
        imagePlaneVertexBuffer.label = "ImagePlaneVertexBuffer"
        
        // Load all the shader files with a metal file extension in the project.
        let defaultLibrary = metalDevice?.makeDefaultLibrary()!
                
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
        CVMetalTextureCacheCreate(nil, nil, metalDevice!, nil, &textureCache)
        cameraImageTextureCache = textureCache
        
        // Define the shaders that will render the camera image on the GPU.
        let vertexFunction = defaultLibrary?.makeFunction(name: "vertexTransform")!
        let fragmentFunction = defaultLibrary?.makeFunction(name: "fragmentShader")!
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.label = "MyPipeline"
        pipelineStateDescriptor.sampleCount = renderDestination.sampleCount
        pipelineStateDescriptor.vertexFunction = vertexFunction
        pipelineStateDescriptor.fragmentFunction = fragmentFunction
        pipelineStateDescriptor.vertexDescriptor = imagePlaneVertexDescriptor
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat

        // Initialize the pipeline.
        do {
            try pipelineState = metalDevice?.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        } catch let error {
            print("Failed to create pipeline state, error \(error)")
        }
        
        // Create the command queue for one frame of rendering work.
        metalCommandQueue = metalDevice?.makeCommandQueue()
        
       
        
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
            
           
                        
            if let renderPassDescriptor = renderDestination.currentRenderPassDescriptor, let currentDrawable = renderDestination.currentDrawable {
                
                if let renderEncoding = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                   
                    // Set a label to identify this render pass in a captured Metal frame.
                    renderEncoding.label = "DepthGUICameraPreview"

                    // Schedule the camera image to be drawn to the screen.
                    doRenderPass(renderEncoder: renderEncoding)

                    // Finish encoding commands.
                    renderEncoding.endEncoding()
                }
                
                // Schedule a present once the framebuffer is complete using the current drawable.
                commandBuffer.present(currentDrawable)
            }
            
            // Finalize rendering here & push the command buffer to the GPU.
            commandBuffer.commit()
            
            
        }
    }
    
    // Schedules the camera image to be rendered on the GPU.
    func doRenderPass(renderEncoder: MTLRenderCommandEncoder) {
        
        guard let cameraImageY = cameraImageTextureY, let cameraImageCbCr = cameraImageTextureCbCr else {
            return
        }

        // Push a debug group that enables you to identify this render pass in a Metal frame capture.
        renderEncoder.pushDebugGroup("CameraPass")

        // Set render command encoder state.
        renderEncoder.setCullMode(.none)
        renderEncoder.setRenderPipelineState(pipelineState)

        let p1 = CGPoint(x: CGFloat(selectionState.x1), y: CGFloat(selectionState.y1)).applying(displayToCameraTransform.inverted())
        let p2 = CGPoint(x: CGFloat(selectionState.x2), y: CGFloat(selectionState.y2)).applying(displayToCameraTransform.inverted())
        var scaledSelectionState = SelectionStruct(x1: Float(min(p1.x, p2.x)*viewportSize.width), x2: Float(max(p1.x, p2.x)*viewportSize.width), y1: Float(min(p1.y, p2.y)*viewportSize.height), y2: Float(max(p1.y, p2.y)*viewportSize.height), editable: selectionState.editable)
        renderEncoder.setFragmentBytes(&scaledSelectionState, length: MemoryLayout<SelectionStruct>.stride, index: 2)
         
        // Setup plane vertex buffers.
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: 1)

        // Setup textures for the camera fragment shader.
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(cameraImageY), index: 0)
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(cameraImageCbCr), index: 1)

        // Draw final quad to display
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.popDebugGroup()
        
        
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
            updateImagePlane(frame: currentFrame)
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
        
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex) // 480  //240
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex) // 360 //180
        
        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, cameraImageTextureCache, pixelBuffer, nil, pixelFormat,
                                                               width, height, planeIndex, &texture)
        
        if status != kCVReturnSuccess {
            texture = nil
        }
        
        return texture
    }
    
    // Sets up vertex data (source and destination rectangles) rendering.
    func updateImagePlane(frame: CVImageBuffer) {
        // Update the texture coordinates of the image plane to aspect fill the viewport.
        //let orientation = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.windowScene?.interfaceOrientation ?? .portrait
        //let cgImageOrientation = CGImagePropertyOrientation(interfaceOrientation: orientation)
        // Convert the image buffer to a CIImage
        //let ciImage = CIImage(cvPixelBuffer: frame)
        //displayToCameraTransform = ciImage.orientationTransform(for: cgImageOrientation).inverted()
        
        // Just a work-around
        displayToCameraTransform = CGAffineTransform(a: 0.0, b: -1.0, c: 1.0, d: 0.0, tx: 0.0, ty: 1.0)
        let vertexData = imagePlaneVertexBuffer.contents().assumingMemoryBound(to: Float.self)
        for index in 0...3 {
            let textureCoordIndex = 4 * index + 2
            let textureCoord = CGPoint(x: CGFloat(kImagePlaneVertexData[textureCoordIndex]), y: CGFloat(kImagePlaneVertexData[textureCoordIndex + 1]))
            let transformedCoord = textureCoord.applying(displayToCameraTransform)
            vertexData[textureCoordIndex] = Float(transformedCoord.x)
            vertexData[textureCoordIndex + 1] = Float(transformedCoord.y)
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
