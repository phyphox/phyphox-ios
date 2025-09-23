//
//  SpectroscopyAnalyzer.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 25.06.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

@available(iOS 14.0, *)
class SpectroscopyAnalyzer: AnalyzingModule {
    
    var result: DataBuffer?
    var xAxis: DataBuffer?
    
    var analyzisPipelineState : MTLComputePipelineState?
    var outputBuffer: MTLBuffer?
    var latestResults = (0..<720).map { Double($0) }
    
    init(result: DataBuffer?, xAxis: DataBuffer?) {
        self.result = result
        self.xAxis = xAxis
    
    }
    
    override func loadMetal() {
        guard let metalDevice = AnalyzingModule.metalDevice else { return }
        let gpuFunctionLibrary = AnalyzingModule.gpuFunctionLibrary
        
        guard let intensityFunction = gpuFunctionLibrary?.makeFunction(name: "readLuminaceVal") else { return }
        
        do {
            analyzisPipelineState = try metalDevice.makeComputePipelineState(function: intensityFunction)
        } catch {
            print("Failed to create pipeline analysis state, error \(error)")
        }
        
    }
    
    override func doUpdate(metalCommandBuffer: any MTLCommandBuffer, cameraImageTextureY: any MTLTexture, cameraImageTextureCbCr: any MTLTexture) {
        
        guard let analyzisEncoding = metalCommandBuffer.makeComputeCommandEncoder() else { return }
        
        guard let analysisPipelineState = self.analyzisPipelineState else {
            print("Failed to create analysisPipelineState")
            analyzisEncoding.endEncoding()
            return
        }
        
        analyzisEncoding.setComputePipelineState(analysisPipelineState)
        
        analyzeTexture(analyzeEncoding: analyzisEncoding, cameraImageTextureY: cameraImageTextureY)
        
    }
    
    func analyzeTexture(analyzeEncoding : MTLComputeCommandEncoder, cameraImageTextureY: MTLTexture){
        guard let metalDevice = AnalyzingModule.metalDevice else { return }
        
        let height = cameraImageTextureY.height // does the height corresponds to the textures height or orientations height // 720
        let width = cameraImageTextureY.width // 1280
        
        let resultWidth = height
        
        let calculatedThreadSize = calculateThreadSize(selectedWidth: height, selectedHeight: 1)
        
        outputBuffer = metalDevice.makeBuffer(length: resultWidth * MemoryLayout<Float>.stride, options: .storageModeShared)
        
        analyzeEncoding.setTexture(cameraImageTextureY, index: 0)
        analyzeEncoding.setBuffer(outputBuffer, offset: 0, index: 0)
        
        analyzeEncoding.dispatchThreadgroups(calculatedThreadSize.gridSize, threadsPerThreadgroup: calculatedThreadSize.threadGroupSize)
        
        analyzeEncoding.endEncoding()
        
    }
    
    
    func analyze(analyzeEncoding : MTLComputeCommandEncoder,
                 cameraImageTextureY: MTLTexture,
                 cameraImageTextureCbCr: MTLTexture){
        
        guard let metalDevice = AnalyzingModule.metalDevice else { return }
        
        let regionWidth = getSelectedArea().width
        let regionHeight = getSelectedArea().height
        
        
        let bufferSize = 1 * regionHeight
        
        let calculateGridAndGroupSize = calculateThreadSize(selectedWidth: 1, selectedHeight: regionHeight)
        
        outputBuffer = metalDevice.makeBuffer(length: regionWidth * MemoryLayout<Float>.stride, options: .storageModeShared)
        
        let selectionBuffer = metalDevice.makeBuffer(bytes: &selectionState, length: MemoryLayout<SelectionState>.size, options: .storageModeShared)
        
        analyzeEncoding.setTexture(cameraImageTextureY, index: 0)
        analyzeEncoding.setTexture(cameraImageTextureCbCr, index: 1)
        analyzeEncoding.setBuffer(outputBuffer, offset: 0, index: 0)
        analyzeEncoding.setBuffer(selectionBuffer, offset: 0, index: 1)
        
        analyzeEncoding.dispatchThreadgroups(calculateGridAndGroupSize.gridSize, threadsPerThreadgroup: calculateGridAndGroupSize.threadGroupSize)
        
        analyzeEncoding.endEncoding()
        
    }
    
    override func prepareWriteToBuffers(cameraSettings: CameraSettingsModel) {
        
        guard let baseAddress = outputBuffer?.contents() else {
            print("Error: buffer.contents() returned nil")
            return
        }
        
        let textureWidth = (outputBuffer?.length ?? 1) / MemoryLayout<Float>.stride
        let luminancePtr = baseAddress.bindMemory(to: Float.self, capacity: textureWidth)
        
        for i in 0..<latestResults.count {
            latestResults[i] = Double(luminancePtr[i])
        }
        
    }
    
    override func writeToBuffers() {
        self.xAxis?.clear(reset: true)
        self.result?.clear(reset: true)
        
        let xAxisValue = Array(0..<(((self.xAxis?.size ?? 1) - 1))).map{ Double($0) }
        self.xAxis?.appendFromArray(xAxisValue)
    
        if let resultBuffer = result {
            resultBuffer.appendFromArray(latestResults)
           
        }
        
    }
    
    func calculateThreadSize(selectedWidth: Int, selectedHeight: Int) -> (threadGroupSize: MTLSize, gridSize: MTLSize, numOfThreadGroups: Int) {
       
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
         // Dispatch the compute shader with the size of the selected bounding box
        let threadgroupsX = (selectedWidth + threadGroupSize.width - 1) / threadGroupSize.width;
        let threadgroupsY = (selectedHeight + threadGroupSize.height - 1) / threadGroupSize.height;
        let _gridSize = MTLSize(width: threadgroupsX, height: threadgroupsY, depth: 1)
        let _numThreadSize = (_gridSize.width * _gridSize.height)
        
        return (threadGroupSize: threadGroupSize, gridSize: _gridSize, numOfThreadGroups: _numThreadSize )
         
    }
    
}

