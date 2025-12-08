//
//  SpectroscopyAnalyzer.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 25.06.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

@available(iOS 14.0, *)
class SpectroscopyAnalyzer: AnalyzingModule {
    

    private enum Constants {
        static let kernelFunctionName = "readLuminaceVal"
        static let threadGroupWidth = 16
        static let threadGroupHeight = 16
    }
    
    var analysisResult: DataBuffer?
    var xAxis: DataBuffer?
    
    var analyzisPipelineState : MTLComputePipelineState?
    var metalOutputBuffer: MTLBuffer?
    private var latestResults: [Double] = []
    private var latestxAxis: [Double] = []
    
    var selectedWidthForAnalysis  = 0
    var selectedHeightForAnalysis  = 0
    
    init(result: DataBuffer?, xAxis: DataBuffer?) {
        self.analysisResult = result
        self.xAxis = xAxis
    }
    
    override func loadMetal() {
        guard let metalDevice = AnalyzingModule.metalDevice else { return }
        let gpuFunctionLibrary = AnalyzingModule.gpuFunctionLibrary
        
        guard let readLuminanceFunction = gpuFunctionLibrary?.makeFunction(name: Constants.kernelFunctionName) else { return }
        
        do {
            analyzisPipelineState = try metalDevice.makeComputePipelineState(function: readLuminanceFunction)
        } catch {
            print("Failed to create pipeline analysis state, error \(error)")
        }
        
    }
    
    override func doUpdate(metalCommandBuffer: any MTLCommandBuffer, cameraImageTextureY: any MTLTexture, cameraImageTextureCbCr: any MTLTexture) {
        
        guard let computeEncoder = metalCommandBuffer.makeComputeCommandEncoder() else { return }
        
        guard let analysisPipelineState = self.analyzisPipelineState else {
            print("Failed to find pipeline state")
            computeEncoder.endEncoding()
            return
        }
        
        computeEncoder.setComputePipelineState(analysisPipelineState)
        
        analyzeTexture(computeEncoder: computeEncoder, cameraImageTextureY: cameraImageTextureY, cameraImageTextureCbCr: cameraImageTextureCbCr)
       
    }
    
    func analyzeTexture(computeEncoder : MTLComputeCommandEncoder, cameraImageTextureY: MTLTexture, cameraImageTextureCbCr: MTLTexture){
        guard let metalDevice = AnalyzingModule.metalDevice else { return }
        
        selectedWidthForAnalysis = Int(selectionState.x2 - selectionState.x1)
        selectedHeightForAnalysis = Int(selectionState.y2 - selectionState.y1)
        
        // Ensure dimensions are valid to prevent crashes
        guard selectedWidthForAnalysis > 0, selectedHeightForAnalysis > 0 else {
            computeEncoder.endEncoding()
            return
        }
        
        let requiredBytes = selectedWidthForAnalysis * MemoryLayout<Float>.stride
        if metalOutputBuffer == nil || metalOutputBuffer!.length < requiredBytes {
            metalOutputBuffer = metalDevice.makeBuffer(length: requiredBytes, options: .storageModeShared)
        }
        
        let selectionBuffer = metalDevice.makeBuffer(bytes: &selectionState, length: MemoryLayout<SelectionState>.size, options: .storageModeShared)
        
        computeEncoder.setTexture(cameraImageTextureY, index: 0)
        computeEncoder.setTexture(cameraImageTextureCbCr, index: 1)
        computeEncoder.setBuffer(metalOutputBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(selectionBuffer, offset: 0, index: 1)
        
        let gridSize = calculateGridSize(width: selectedWidthForAnalysis, height: selectedHeightForAnalysis)
        
        computeEncoder.dispatchThreadgroups(gridSize.threadgroups, threadsPerThreadgroup: gridSize.threadsPerThreadgroup)
        computeEncoder.endEncoding()
        
    }
    
    override func prepareWriteToBuffers(cameraSettings: CameraSettingsModel) {
        
        guard let buffer = metalOutputBuffer, selectedWidthForAnalysis > 0 else { return }
        
        let luminancePointer = buffer.contents().bindMemory(to: Float.self, capacity: selectedWidthForAnalysis)
        
        if latestResults.count != selectedWidthForAnalysis {
            latestResults = Array(repeating: 0.0, count: selectedWidthForAnalysis)
        }
        
        for i in 0..<selectedWidthForAnalysis {
            latestResults[i] = Double(luminancePointer[i])
        }
    }
    
    override func writeToBuffers() {
        self.xAxis?.clear(reset: true)
        self.analysisResult?.clear(reset: true)
        
        guard selectedWidthForAnalysis > 0 else { return }
        
        if latestxAxis.count != (selectedWidthForAnalysis - 1) {
            latestxAxis = (0..<(selectedWidthForAnalysis - 1)).map { Double($0) }
                }
        
        self.xAxis?.appendFromArray(latestxAxis)
        self.analysisResult?.appendFromArray(latestResults)

    }
    
    func calculateGridSize(width: Int, height: Int) -> (threadgroups: MTLSize, threadsPerThreadgroup: MTLSize) {
       
        let threadsPerGroup = MTLSize(width: Constants.threadGroupWidth,
                                              height: Constants.threadGroupHeight,
                                              depth: 1)
        
        let threadgroupsX = (width + threadsPerGroup.width - 1) / threadsPerGroup.width
        let threadgroupsY = (height + threadsPerGroup.height - 1) / threadsPerGroup.height
                
        let threadgroups = MTLSize(width: threadgroupsX, height: threadgroupsY, depth: 1)
                
        return (threadgroups, threadsPerGroup)
         
    }
    
}

