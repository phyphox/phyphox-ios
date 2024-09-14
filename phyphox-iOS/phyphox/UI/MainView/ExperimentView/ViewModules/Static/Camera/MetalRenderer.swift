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

/*
phyphox xml -> ExperimentCameraInput (cameraInput in the Experiment) creates ExperimentCameraInputSession
    - Each of this cameraInput has one session of cameraInput which can be called from viewmodel. 
 ExperimentCameraInputSession includes all the session from the current inputs, like x1 x2 values
 and also does the cameramodel instantiation and pass the xml values into camera model. 
 
 So in this session from ViewModel(which contains UI) the UI is passed to  ExperimentCameraInputSession
 This setstup the required delegates
 
 When ExperimentCameraInputSession instantitaes CameraModel, the CameraModel then instantiates CameraService and MetalRenderer and CameraSettingModels (which contains all the settings that can be applied to camera)
 
 CameraModel also configues the all the required permissions, and if ok then start the cameraSession which also has a capture Output which runs on every frame that resides in cameraService
 This capture output then calles updateFrame in MetalRenderer and passes the new frames and selections areas. 
 This update is done for CPU part
 
 MetalRenderer calls draw function at each loop and this called update() which passes the buffers to the GPU
    
 */


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
    
    var hsvPipeLineState: MTLComputePipelineState!
    
    var finalSumPipelineState: MTLComputePipelineState!
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
        
        var padding: (UInt8, UInt8, UInt8) = (0, 0, 0)
    }
    

    var lumaAnalyser: LumaAnalyser
    
    init(renderer: MTKView) {
        
        self.renderDestination = renderer
        
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.metalDevice = metalDevice
        }
        
        lumaAnalyser = LumaAnalyser(metalDevice: metalDevice)
       
        super.init()
     
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
    
    var timeStampOfFrame: TimeInterval = TimeInterval()
    
    func updateFrame(imageBuffer: CVImageBuffer!, selectionState: SelectionStruct, time: TimeInterval) {
        
        if imageBuffer != nil {
            
            self.cvImageBuffer = imageBuffer
        }
        
        //timeStampOfFrame = time
        
        self.selectionState = selectionState
        
        if measuring {
            timeStampOfFrame = time
            //getLuminance(time: time)
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
            
            guard let ytexture = cameraImageTextureY else {
                print("empty texture")
                return
            }
            
            let texturee = CVMetalTextureGetTexture(ytexture)
            
            let textureWidth = texturee?.width ?? 1
            let textureHeight = texturee?.height ?? 1
            let region = MTLRegionMake2D(0, 0, textureWidth , textureHeight )
            
            let bytesPerPixel = 1
            let bytesPerRow = (textureWidth) * bytesPerPixel
            
            
            var pixelData = [UInt8](repeating: 0, count: (textureWidth ) * (textureHeight ) * bytesPerPixel)
            
            texturee?.getBytes(&pixelData, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
            
            /**
            for y in 0..<textureHeight {
                for x in 0..<textureWidth {
                    let index = (y * textureWidth + x) * bytesPerPixel
                    let r = pixelData[index]      // Red
                    if(y == 0){
                        print("Pixel at (\(x), \(y)): R=\(r)")
                    }
                    
                }
            }
             
             */
            
            
            
            let data = Data( )
            
            let fileURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let outputFile = fileURL.appendingPathComponent("texture").appendingPathExtension("txt")
            
            print("filepath ", outputFile.path)
            do {
                try data.write(to: outputFile)
            } catch{
                print("error ", error.localizedDescription)
            }
            
            bufferExtracted = true
            
            
            
            
            /**
            // 173641
             
            for y in 0...textureHeight {
                for x in 0...textureWidth {
                   // let l = (typedPointerToYPlane?[Int(y) * Int(lData.rowBytes) + Int(x)] ?? 0) & 0xFF
                   
                    luminance += Int(l)
                   
                    if(luminance > 0){
                        nonZeroCount += 1
                    }
                    
                }
            }
             */
            
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
    
    private func dataIn(z: Double) {
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
        
        let t = timeReference.getExperimentTimeFromEvent(eventTime: timeStampOfFrame)
        
        if t >= timeReference.timeMappings.last?.experimentTime ?? 0.0 {
            self.writeToBuffers(z: z, t: t)
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
    
   
    var analysisPipelineState: MTLComputePipelineState!
   
    

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
        
        //lumaAnalyser = LumaAnalyser(metalDevice: metalDevice)
        lumaAnalyser.loadMetal()
        
        // Create the command queue for one frame of rendering work.
        metalCommandQueue = metalDevice.makeCommandQueue()
        
        
        
        //loadGpuForAnalysis()
        
    }
    
    
    
    func loadGpuForAnalysis(){
        let gpuFunctionLibrary = metalDevice.makeDefaultLibrary()
       
        
        let luminaceFunction = gpuFunctionLibrary?.makeFunction(name: "computeSumLuminanceParallel")
        do {
            analysisPipelineState = try metalDevice.makeComputePipelineState(function: luminaceFunction!)
            
        } catch {
          print("Failed to create pipeline state, error \(error)")
        }
        
        let finalSum = gpuFunctionLibrary?.makeFunction(name: "computeFinalSum")
        do {
            finalSumPipelineState = try metalDevice.makeComputePipelineState(function: finalSum!)
        } catch  {
            print("Failed to create pipeline state, error \(error)")
        }
         
        /**
        let hsvFunction = gpuFunctionLibrary?.makeFunction(name: "computeHSV")
        do {
            hsvPipeLineState = try metalDevice.makeComputePipelineState(function: hsvFunction!)
        } catch  {
            print("Failed to create pipeline state, error \(error)")
        }
         */
       
        
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
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            
            
            
            
             
            
             
            /**
            if let hsvAnalysisCommandBuffer = metalCommandQueue.makeCommandBuffer(){
                let startTime = Date()
                
                hsvAnalysisCommandBuffer.addCompletedHandler{ commandBuffer in
                    let endTime = Date()
                    
                    let executionTime = endTime.timeIntervalSince(startTime)
                    print("executionTime : \(executionTime)")
                }
                
                if let analysisEncoding = hsvAnalysisCommandBuffer.makeComputeCommandEncoder() {
                    analyseHSV(analyseEncoding: analysisEncoding, analysisCommandBuffer: hsvAnalysisCommandBuffer)
                }
            }
             */
            
            
            // Finalize rendering here & push the command buffer to the GPU.
            
            
            
        }
        
        
        if let analysisCommandBuffer = metalCommandQueue.makeCommandBuffer() {
            
            checkTimeInterval(metalCommandBuffer: analysisCommandBuffer)
            
            guard let ytexture = cameraImageTextureY else {
                return
            }
            
            guard let texturee = CVMetalTextureGetTexture(ytexture) else {
                return
            }
            
           
            lumaAnalyser.update(texture: texturee,
                                selectionArea: getSelectionState(),
                                metalCommandBuffer: analysisCommandBuffer)
        }
         
        /**
        if let analysisCommandBuffer = metalCommandQueue.makeCommandBuffer() {
            
            let startTime = Date()
            
            analysisCommandBuffer.addCompletedHandler { commandBuffer in
                let endTime = Date()
                let executionTime = endTime.timeIntervalSince(startTime)
                print("executionTime : \(executionTime)")
            }
            
            
            
            if let analysisEncoding = analysisCommandBuffer.makeComputeCommandEncoder() {
                
                analyseLuminance(analysisEncoding: analysisEncoding, analysisCommandBuffer: analysisCommandBuffer)
                
                //analyseHSV(analyseEncoding: analysisEncoding, analysisCommandBuffer: analysisCommandBuffer)
                
            }
            
           
        }
         
         */
        
        
        
        
    }
    
    func checkTimeInterval(metalCommandBuffer: MTLCommandBuffer){
        let startTime = Date()
        
        metalCommandBuffer.addCompletedHandler { commandBuffer in
            let endTime = Date()
            let executionTime = endTime.timeIntervalSince(startTime)
            print("executionTime : \(executionTime)")
           
            if self.measuring {
                var luma = self.lumaAnalyser.lumaFinalValue()
                self.dataIn(z: Double(luma))
                //getLuminance(time: time)
            }
            
            
            
        }
    }
    
    struct PartialBufferLength {
        var length : Int
    };
    
    
    func totalSum(analyseEncoding : MTLComputeCommandEncoder, analysisCommandBuffer: MTLCommandBuffer){
     
        
    }
    
    
    func analyseHSV(analyseEncoding : MTLComputeCommandEncoder, analysisCommandBuffer: MTLCommandBuffer) {
     
        guard let cameraImageY = cameraImageTextureY, let cameraImageCbCr = cameraImageTextureCbCr else {
            analyseEncoding.endEncoding()
            return
        }
        
        analyseEncoding.setComputePipelineState(hsvPipeLineState)
        
        
        let result = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
        let saturationBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
        let valueBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
        
        analyseEncoding.setTexture(CVMetalTextureGetTexture(cameraImageY), index: 0)
        analyseEncoding.setTexture(CVMetalTextureGetTexture(cameraImageCbCr), index: 1)
        analyseEncoding.setBuffer(result, offset: 0, index: 0)
        //analyseEncoding.setBuffer(saturationBuffer, offset: 0, index: 1)
        //analyseEncoding.setBuffer(valueBuffer, offset: 0, index: 2)
        
        analyseEncoding.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
        
        analyseEncoding.endEncoding()
        analysisCommandBuffer.commit()
        analysisCommandBuffer.waitUntilCompleted()
        
        let resultBuffer = result.contents().bindMemory(to: Float.self, capacity: 0)
        
        print("resultBuffer: ", resultBuffer.pointee)
    }
    
    
    var bufferExtracted = false
    
    func analyseLuminance(analysisEncoding: MTLComputeCommandEncoder, analysisCommandBuffer: MTLCommandBuffer){
        
        guard let ytexture = cameraImageTextureY else {
            print("empty texture")
            analysisEncoding.endEncoding()
            return
        }
        
        guard let texturee = CVMetalTextureGetTexture(ytexture) else {
            return
        }
        
        print("texture width \(texturee.width) height \(texturee.height) arrayLength\(texturee.arrayLength) " +
              "pixelformat \(texturee.pixelFormat.rawValue) bufferBytesPerRow \(texturee.bufferBytesPerRow) ")
        
        analysisEncoding.setComputePipelineState(analysisPipelineState)
        
        //let resultBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
        //let countResultBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.size, options: .storageModeShared)!
        
        var _selectionState =  getSelectionState()
        let selectionBuffer = metalDevice.makeBuffer(bytes: &_selectionState,length: MemoryLayout<SelectionStruct>.size,options: .storageModeShared)
        
        let _width = Int((_selectionState.x2 - _selectionState.x1 + 1))
        let _height = Int((_selectionState.y2 - _selectionState.y1 + 1))
       
        let calculatedGridAndGroupSize = calculateThreadSize(selectedWidth: 360, selectedHeight: 480)
        
        let w = analysisPipelineState.threadExecutionWidth
        let h = analysisPipelineState.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSizeMake(16, 16, 1)
        
        let threadsPerGrid = MTLSize(width: texturee.width,
                                     height: texturee.height,
                                     depth: 1)
        
        
        let threadGroupSize = calculatedGridAndGroupSize.threadGroupSize
       
        let gridSize = calculatedGridAndGroupSize.gridSize
        let numThreadGroups = (gridSize.width * gridSize.height)
       
         
        let partialBuffer = metalDevice.makeBuffer(length: MemoryLayout<Int>.stride * numThreadGroups,options: .storageModeShared)!
       
        analysisEncoding.setTexture(texturee, index: 0)
        //analysisEncoding.setBuffer(resultBuffer, offset: 0, index: 0)
        analysisEncoding.setBuffer(partialBuffer, offset: 0, index: 0)
        analysisEncoding.setBuffer(selectionBuffer, offset: 0, index: 1)
        
         // 0.03 time if we set groupsize 1 by 1 and gridsize 1 by 1
        analysisEncoding.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadsPerThreadgroup)
        
        analysisEncoding.endEncoding()
        
        let result = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
        let countResultBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.size, options: .storageModeShared)!
        
        if let totalSumEncoding = analysisCommandBuffer.makeComputeCommandEncoder() {
            
            totalSumEncoding.setComputePipelineState(finalSumPipelineState)
            
            var partialLengthStruct = PartialBufferLength(length: numThreadGroups)
           
            let arrayLength = metalDevice.makeBuffer(bytes: &partialLengthStruct,length: MemoryLayout<PartialBufferLength>.size,options: .storageModeShared)
            
            totalSumEncoding.setBuffer(partialBuffer, offset: 0, index: 0)
            totalSumEncoding.setBuffer(result, offset: 0, index: 1)
            totalSumEncoding.setBuffer(arrayLength, offset: 0, index: 2)
            totalSumEncoding.setBuffer(countResultBuffer, offset: 0, index: 3)
            
            totalSumEncoding.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(numThreadGroups, 1, 1))
            
            totalSumEncoding.endEncoding()
            
        }
        
        analysisCommandBuffer.commit()
        analysisCommandBuffer.waitUntilCompleted()
        
        let resultBuffer = result.contents().bindMemory(to: Float.self, capacity: 0)
        
        print("resultBuffer: ", resultBuffer.pointee)
        
        // Discuss the issue about difference in average luminance value when changing the selection region.
        // Access the results
        
        let countResultPointer = countResultBuffer.contents().bindMemory(to: Float.self, capacity: 1)
        print("countResultPointer: \(countResultPointer.pointee)")
        let _partialBuffer = partialBuffer.contents().bindMemory(to: Float.self, capacity: 1)
        // 98 * 72 7056
        let analysisArea = (_selectionState.x2 - _selectionState.x1 ) * (_selectionState.y2 - _selectionState.y1)
        
        // Create a buffer pointer for easy access to all the values
        let bufferPointer = UnsafeMutableBufferPointer<Float>(start: _partialBuffer, count: numThreadGroups)
        
        /**
        for i in 0...(numThreadGroups-1){
            print("index \(bufferPointer[i]) for \(i)")
        }
         */

       // print("total Luminance: \(resultPointer.pointee)")
        //print("Average Luminance: \(averageLuminance)")
        print("analysisArea: \(480 * 360)")
        //print("countResultPointer: \(countResultPointer.pointee)")
        print("partialBuffer: \(_partialBuffer.pointee)")
        
        
        print("selection state x1 \(_selectionState.x1), y1 \(_selectionState.y1) ")
        print("selection state x2 \(_selectionState.x2), y2 \(_selectionState.y2) ")
    }
    
    var numThreadGroups = 0
    
    // from A11, (that means from Iphone 8), it supports  nonuniform threadgroups
    // so before that we need to calculate to get the threadgroup and thread size
  
    func calculateThreadSize(selectedWidth: Int, selectedHeight: Int) -> (threadGroupSize: MTLSize, gridSize: MTLSize) {
       
         //0.003
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
         // Dispatch the compute shader with the size of the selected bounding box
         let threadgroupsX = (selectedWidth + threadGroupSize.width - 1) / threadGroupSize.width;
         let threadgroupsY = (selectedHeight + threadGroupSize.height - 1) / threadGroupSize.height;
         let _gridSize = MTLSize(width: threadgroupsX, height: threadgroupsY, depth: 1)
        numThreadGroups = (_gridSize.width * _gridSize.height)
        
        return (threadGroupSize: threadGroupSize, gridSize: _gridSize)
         
    }
    
    
    func getSelectionState() -> SelectionStruct{
        let p1 = CGPoint(x: CGFloat(selectionState.x1), y: CGFloat(selectionState.y1))
            .applying(displayToCameraTransform.inverted())
        let p2 = CGPoint(
            x: CGFloat(selectionState.x2), y: CGFloat(selectionState.y2)
        ).applying(displayToCameraTransform.inverted())
        return SelectionStruct(x1: Float(min(p1.x, p2.x)*480),
                               x2: Float(max(p1.x, p2.x)*480),
                               y1: Float(min(p1.y, p2.y)*360),
                               y2: Float(max(p1.y, p2.y)*360),
                               editable: selectionState.editable)
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
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, cameraImageTextureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)
        
        if status != kCVReturnSuccess {
            texture = nil
        }
        
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
    
    func getTextureBytes(texture: MTLTexture) -> [UInt8]? {
        // Define the size of the texture
        let width = texture.width
        let height = texture.height
        let bytesPerPixel = 1 // Assuming RGBA

        // Calculate the total bytes required for the texture
        let totalBytes = width * height * bytesPerPixel

        // Allocate a buffer to store the texture data
        var pixelData = [UInt8](repeating: 0, count: totalBytes)

        // Define the region to extract
        let region = MTLRegionMake2D(0, 0, width, height)

        // Copy texture data into pixelData buffer
        texture.getBytes(&pixelData,
                         bytesPerRow: width * bytesPerPixel,
                         from: region,
                         mipmapLevel: 0)

        return pixelData
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
