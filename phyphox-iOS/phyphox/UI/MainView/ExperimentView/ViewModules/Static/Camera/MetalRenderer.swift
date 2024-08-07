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
    
    var metalDevice: MTLDevice!
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
    
    var defaultVideoDevice: AVCaptureDevice? = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    
    var timeReference: ExperimentTimeReference?
    var cameraBuffers: ExperimentCameraBuffers?
    
    private var queue: DispatchQueue?
    
    struct SelectionStruct {
        var x1, x2, y1, y2: Float
        var editable: Bool
    }
    
    
    var addFunctionPSO: MTLComputePipelineState!
    
    
    init(renderer: MTKView) {
        
        self.renderDestination = renderer
        
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.metalDevice = metalDevice
        }
       
        
        
        super.init()
     
        // Create our random arrays
        // array1 = getRandomArray()
        // array2 = getRandomArray()

        
        loadMetal()
        
    }
    
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("mtkView ", size)
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
            //let startTime = Date()
            getLuminance(time: time)
            //sendComputeCommand()
            //computeInCPU(arr1: array1, arr2: array2)
            //computeInGPU(arr1: array1, arr2: array2)
            //let endTime = Date()
            //let executionTime = endTime.timeIntervalSince(startTime)
            //print("Execution time using Date: \(executionTime) seconds")
        }
        
    }
    
    func start(queue: DispatchQueue) throws {
        self.queue = queue
    }

    // Human eyes doesnot perceive lunimance in linear fashion ?
    // difference between 101 light bulb and 102 light buld is not much but the difference between 1 and 2 light buld is significant
    // cameras are different, how much light reflects it during certain amount of time.
        // captures photons from the light through image sensor and stores how much photos are in certain period of time and stores it into file
    // as it captures the number of photons captured, it naturally perceives light in linear fashion.

    func analyseLuminance(time: Double){
      
    }
    
   
  
    func getLuminance(time: Double){
        
        if let pixelBuffer = self.cvImageBuffer{
            
            var luminance = 00
            
            CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
            let YPlaneBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
            let YPlanewidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
            let YPlaneHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
            let YPlaneRowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
            
            let lData = vImage_Buffer(data: YPlaneBaseAddress, height: vImagePixelCount(YPlaneHeight), width: vImagePixelCount(YPlanewidth), rowBytes: YPlaneRowBytes)
            
            
            let UVBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
            let chromaWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1)
            let chromaHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
            let chromaRowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
            
            _ = vImage_Buffer(data: UVBaseAddress, height: vImagePixelCount(chromaHeight), width: vImagePixelCount(chromaWidth), rowBytes: chromaRowBytes)
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
            
            let rawPointerToYPlaneBaseAddress = UnsafeMutableRawPointer(YPlaneBaseAddress)
            
            let typedPointerToYPlane = rawPointerToYPlaneBaseAddress?.assumingMemoryBound(to: Pixel_8.self)
            
            var nonZeroCount = 0
            // 173641
            for y in 0...lData.height {
                for x in 0...lData.width {
                    let l = (typedPointerToYPlane?[Int(y) * Int(lData.rowBytes) + Int(x)] ?? 0) & 0xFF
                    luminance += Int(l)
                   
                    if(luminance > 0){
                        nonZeroCount += 1
                    }
                    
                }
            }
            
            print("nonZeroCount .. ", nonZeroCount)
            print("lData.height .. ", lData.height)
            print("lData.width .. ", lData.width)
            
            let xmin = Int(self.selectionState.x1 * Float(lData.width))
            let xmax = Int(self.selectionState.x2 * Float(lData.width))
            let ymin = Int(self.selectionState.y1 * Float(lData.height))
            let ymax = Int(self.selectionState.y2 * Float(lData.height))
            
            /**
             xmin = 0.4 * 480 =  192
             xmax = 0.6 * 480 =  288
             ymin = 0.4 * 360 = 144
             ymax = 0.6 * 360 =  216
             
             analysis Area = 96 * 72 = 6912
             
             luminance = 77348.55
             
             average = 77348.55 / 6912
             
             11.
             
             
             
             
             */
            
            
            let analysisArea = (xmax - xmin) * (ymax - ymin)
            
            print("luminance ",luminance)
            
            luminance /= analysisArea * 255
            
            dataIn(z: Double(luminance), time: time)
            
            
        } else {
            //  If the CVImageBuffer is not a CVPixelBuffer, you may need to perform conversion
            
        }
    }
    
    
    private func writeToBuffers(z: Double, t: TimeInterval) {
        if let zBuffer = cameraBuffers?.luminanceBuffer {
            zBuffer.append(z)
        }
        
        if let tBuffer = cameraBuffers?.tBuffer {
            tBuffer.append(t)
        }
    }
    
    private func dataIn(z: Double, time: TimeInterval) {
        guard let zBuffer = cameraBuffers?.luminanceBuffer else {
            print("Error: zBuffer not set")
            return
        }
        guard let tBuffer = cameraBuffers?.tBuffer else {
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
    
    let count: Int = 3000000
    
    var textureCacheAnalysis: CVMetalTextureCache!
    var inTexture: MTLTexture!
    var outTexture: MTLTexture!
    
    
   
    var analysisPipelineState: MTLComputePipelineState!
    
    

    /**
    func computeInGPU(arr1: [Float], arr2: [Float]){
        
        let startTime = CFAbsoluteTimeGetCurrent()
            
            loadGpuForAnalysis()
            
            
            print()
            print("GPU Way")

           

           /**
            // Figure out how many threads we need to use for our operation
            let threadsPerGrid = MTLSize(width: count, height: 1, depth: 1)
            let maxThreadsPerThreadgroup = additionComputePipelineState.maxTotalThreadsPerThreadgroup // 1024
            let threadsPerThreadgroup = MTLSize(width: maxThreadsPerThreadgroup, height: 1, depth: 1)
            commandEncoder?.dispatchThreads(threadsPerGrid,
                                            threadsPerThreadgroup: threadsPerThreadgroup)
            */
           

            // Get the pointer to the beginning of our data
            var resultBufferPointer = resultBuff?.contents().bindMemory(to: Float.self,
                                                                        capacity: MemoryLayout<Float>.size * count)

            // Print out all of our new added together array information
            for i in 0..<3 {
                print("\(arr1[i]) + \(arr2[i]) = \(Float(resultBufferPointer!.pointee) as Any)")
                resultBufferPointer = resultBufferPointer?.advanced(by: 1)
            }
            
            // Print out the elapsed time
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            print("Time elapsed \(String(format: "%.05f", timeElapsed)) seconds")
            print()

        
    }
     */
    
    // Helper function
    func getRandomArray()->[Float] {
        var result = [Float].init(repeating: 0.0, count: count)
        for i in 0..<count {
            result[i] = Float(arc4random_uniform(10))
        }
        return result
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
        pipelineStateDescriptor.label = "MyPipeline"
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
        
        // Create the command queue for one frame of rendering work.
        metalCommandQueue = metalDevice.makeCommandQueue()
        
        
        loadGpuForAnalysis()
        
        
    }
    
    func loadGpuForAnalysis(){
        let gpuFunctionLibrary = metalDevice.makeDefaultLibrary()
        let additionGPUFunction = gpuFunctionLibrary?.makeFunction(name: "computeSumLuminance")
        do {
            analysisPipelineState = try metalDevice.makeComputePipelineState(function: additionGPUFunction!)
        } catch {
          print("Failed to create pipeline state, error \(error)")
        }
    }
    
    
    /**
     
     MTL workflow
     
     NOTE: need to have only one commandQueue and one device per application
     // setup for only once at very start
     1) Create metal device MTLCreateSystemDefaultDevice() // rpresentation for GPU
     2) create commandQueue with device.makeCommandQueue() // this will hold all out command buffers
     
     //
     3) create commandBuffer from the command queue // this will hold all the commands
     4) create render command encoder for all the commands with commandBuffer.makeRenderCommandEncoder(descriptor:) // currentrenderpassdescriptor??
     5) command.endEncoding(), commandBuffer.present(), commandBuffer.commit() , will present the commands and commit to gpu
     
     
     
     
     
     */
    
    
    
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
                    renderEncoding.label = "CameraGUIPreview"
                    
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
        
        //_ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if let analysisCommandBuffer = metalCommandQueue.makeCommandBuffer() {
            
            
            
            if let analysisEncoding = analysisCommandBuffer.makeComputeCommandEncoder() {
                
                guard let ytexture = cameraImageTextureY else {
                    print("empty texture")
                    analysisEncoding.endEncoding()
                    return
                }
                
              
                analysisEncoding.setComputePipelineState(analysisPipelineState)
                
                let resultBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
               
                //resultPointer.pointee = 0.0
                
                
                  // Create a buffer to store the sum of luminance values
                  let sumResultBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.size, options: .storageModeShared)!
                  // Create a buffer to store the count of non-zero luminance values
                  let countResultBuffer = metalDevice.makeBuffer(length: MemoryLayout<UInt32>.size, options: .storageModeShared)!

                  
                
                let texturee = CVMetalTextureGetTexture(ytexture)
                
                
                analysisEncoding.setTexture(texturee, index: 0)
                analysisEncoding.setBuffer(resultBuffer, offset: 0, index: 0)
                analysisEncoding.setBuffer(sumResultBuffer, offset: 0, index: 1)
                analysisEncoding.setBuffer(countResultBuffer, offset: 0, index: 2)
                
                // Set up thread group sizes (one thread group for simplicity)
                let threadGroupSize = MTLSize(width: 1, height: 1, depth: 1)
                let gridSize = MTLSize(width: 1, height: 1, depth: 1)
                
                analysisEncoding.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadGroupSize)
                
                analysisEncoding.endEncoding()
                
                analysisCommandBuffer.commit()
                analysisCommandBuffer.waitUntilCompleted()
                
        
                // Access the results
                var resultPointer = resultBuffer.contents().bindMemory(to: Float.self, capacity: 1)
                let sumResultPointer = sumResultBuffer.contents().bindMemory(to: Float.self, capacity: 1)
                let countResultPointer = countResultBuffer.contents().bindMemory(to: UInt32.self, capacity: 1)

              
                let luminanceSum = sumResultPointer.pointee
                let nonZeroCount = countResultPointer.pointee

                
                print("Total Luminance Sum: \(luminanceSum)")
                print("Non-Zero Luminance Count: \(nonZeroCount)")
                
                let xmin = Int(self.selectionState.x1 * 480)
                let xmax = Int(self.selectionState.x2 * 480)
                let ymin = Int(self.selectionState.y1 * 360)
                let ymax = Int(self.selectionState.y2 * 360)
                
                let analysisArea = (xmax - xmin) * (ymax - ymin)
                
                let averageLuminance = resultPointer.pointee / Float(analysisArea)
                
                print("Average Luminance: \(averageLuminance)")
                
                print("analysisArea: \(analysisArea)")
                
                
                print("selection state x1 ", self.selectionState.x1)
                print("selection state x2 ", self.selectionState.x2)
                print("selection state y1 ", self.selectionState.y1)
                print("selection state y2 ", self.selectionState.y2)

                
            }
            
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
        
        // Create output texture
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: 480, height: 360, mipmapped: false)
                textureDescriptor.usage = [.shaderRead, .shaderWrite]
                outTexture = metalDevice.makeTexture(descriptor: textureDescriptor)
        
        return texture
    }
    
    // Sets up vertex data (source and destination rectangles) rendering.
    func updateImagePlane(frame: CVImageBuffer) {
        displayToCameraTransform = transformForDeviceOrientation()

        let vertexData = imagePlaneVertexBuffer.contents().assumingMemoryBound(to: Float.self)
        for index in 0...3 {
            let textureCoordIndex = 4 * index + 2
            let textureCoord = CGPoint(x: CGFloat(kImagePlaneVertexData[textureCoordIndex]), y: CGFloat(kImagePlaneVertexData[textureCoordIndex + 1]))
            let transformedCoord = textureCoord.applying(displayToCameraTransform)
            vertexData[textureCoordIndex] = Float(transformedCoord.x)
            vertexData[textureCoordIndex + 1] = Float(transformedCoord.y)
        }
    }
    
    func transformForDeviceOrientation() -> CGAffineTransform {
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
