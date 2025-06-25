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
    
    var analyzisPipelineState : MTLComputePipelineState?
    
    init(result: DataBuffer?) {
        self.result = result
    }
    
    override func loadMetal() {
        guard let metalDevice = AnalyzingModule.metalDevice else { return }
        let gpuFunctionLibrary = AnalyzingModule.gpuFunctionLibrary
        
        guard let intensityFunction = gpuFunctionLibrary?.makeFunction(name: "") else { return }
        
        do {
            analyzisPipelineState = try metalDevice.makeComputePipelineState(function: intensityFunction)
        } catch {
            print("Failed to create pipeline analysis state, error \(error)")
        }
        
        
    }
    
    override func doUpdate(metalCommandBuffer: any MTLCommandBuffer, cameraImageTextureY: any MTLTexture, cameraImageTextureCbCr: any MTLTexture) {
        
        if let analyzisEncoding = metalCommandBuffer.makeComputeCommandEncoder() {
            analyze(analyzeEncoding: analyzisEncoding, analysisCommandBuffer: metalCommandBuffer, cameraImageTextureY: cameraImageTextureY)
        }
        
    }
    
    func analyze(analyzeEncoding : MTLComputeCommandEncoder,
                 analysisCommandBuffer: MTLCommandBuffer,
                 cameraImageTextureY: MTLTexture?){
        
        guard let luminanceTexture = cameraImageTextureY else { return }
        
        guard let metalDevice = AnalyzingModule.metalDevice else { return }
        
        guard let analysisPipelineState = self.analyzisPipelineState else {
            print("Failed to create analysisPipelineState")
            analyzeEncoding.endEncoding()
            return
        }
        
        analyzeEncoding.setComputePipelineState(analysisPipelineState)
        
        let totalHeight = luminanceTexture.height
        let totalWidth = luminanceTexture.width
        
        let regionWidth = getSelectedArea().width
        let regionHeight = getSelectedArea().height
        
        let xOrigin = selectionState.x1 * Float(totalHeight)
        let yOrigin = selectionState.y1 * Float(totalWidth)
        
        let bufferSize = regionWidth * regionHeight
        
        let outputBuffer = metalDevice.makeBuffer(length: bufferSize, options: .storageModeShared)
        
        let origin = MTLOrigin(x: Int(xOrigin), y: Int(yOrigin), z: 0)
        let regionSize = MTLSize(width: regionWidth, height: regionHeight, depth: 1)
        
        let sizeBuffer = metalDevice.makeBuffer(bytes: [UInt32(regionSize.width), UInt32(regionSize.height)], length: MemoryLayout<simd_uint2>.stride, options: [])
        
        
        
        
    }
    
    override func prepareWriteToBuffers(cameraSettings: CameraSettingsModel) {
        
        
        
    }
    
    override func writeToBuffers() {
        
    }
}
