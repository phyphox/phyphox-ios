//
//  LuminanceAnalyzer.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 14.09.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

@available(iOS 14.0, *)
class LuminanceAnalyzer: AnalyzingModule {
    
    var resultBuffer: Double = 0.0
    
    var analysisPipelineState : MTLComputePipelineState?
    var finalSumPipelineState : MTLComputePipelineState?
    
    var time: TimeInterval = TimeInterval()

    var result: DataBuffer?
    
    init(result: DataBuffer?) {
        self.result = result
       
    }
    
    override func loadMetal() {
        
        guard let metalDevice = AnalyzingModule.metalDevice else { return }
        
        let gpuFunctionLibrary = AnalyzingModule.gpuFunctionLibrary
        
        guard let luminanceFunction = gpuFunctionLibrary?.makeFunction(name:"computeLuminance") else {
            return
        }
        do {
            analysisPipelineState = try metalDevice.makeComputePipelineState(function: luminanceFunction)
        } catch  {
            print("Failed to create pipeline analysis state, error \(error)")
        }
        
        let finalSum = gpuFunctionLibrary?.makeFunction(name: "computeFinalSum")
        do {
            finalSumPipelineState = try metalDevice.makeComputePipelineState(function: finalSum!)
        } catch  {
            print("Failed to create pipeline final sum state, error \(error)")
        }
        
    }
    
    override func doUpdate(metalCommandBuffer: MTLCommandBuffer,
                cameraImageTextureY: MTLTexture?,
                cameraImageTextureCbCr: MTLTexture? ) {
        
        if let analysisEncoding = metalCommandBuffer.makeComputeCommandEncoder() {
            analyze(analyzeEncoding : analysisEncoding,
                    analysisCommandBuffer: metalCommandBuffer,
                    cameraImageTextureY: cameraImageTextureY,
                    cameraImageTextureCbCr: cameraImageTextureCbCr)
        }
        
        
    }
    
    var luminanceValue : MTLBuffer?
    func analyze(analyzeEncoding : MTLComputeCommandEncoder,
                 analysisCommandBuffer: MTLCommandBuffer,
                 cameraImageTextureY: MTLTexture?,
                 cameraImageTextureCbCr: MTLTexture?) {
        
        guard let metalDevice = AnalyzingModule.metalDevice else { return }
        
        guard let analysisPipelineState = self.analysisPipelineState else {
            print("Failed to create analysisPipelineState")
            analyzeEncoding.endEncoding()
            return
        }
        
        guard let finalSumPipelineState = self.finalSumPipelineState else {
            print("Failed to create finalSumPipelineState")
            analyzeEncoding.endEncoding()
            return
        }
        
        analyzeEncoding.setComputePipelineState(analysisPipelineState)
        
        let calculatedGridAndGroupSize = calculateThreadSize(selectedWidth: getSelectedArea().width, selectedHeight: getSelectedArea().height)
        
        let partialBufferLength = calculatedGridAndGroupSize.numOfThreadGroups
        //setup buffers
        let selectionBuffer = metalDevice.makeBuffer(bytes: &selectionState,length: MemoryLayout<SelectionState>.size,options: .storageModeShared)
        let partialBuffer = metalDevice.makeBuffer(length: MemoryLayout<Int>.stride * partialBufferLength,options: .storageModeShared)!
        
        analyzeEncoding.setTexture(cameraImageTextureY, index: 0)
        analyzeEncoding.setTexture(cameraImageTextureCbCr, index: 1)
        analyzeEncoding.setBuffer(partialBuffer, offset: 0, index: 0)
        analyzeEncoding.setBuffer(selectionBuffer, offset: 0, index: 1)
        
        analyzeEncoding.dispatchThreadgroups(calculatedGridAndGroupSize.gridSize,
                                             threadsPerThreadgroup: calculatedGridAndGroupSize.threadGroupSize)
        
        analyzeEncoding.endEncoding()
        
        luminanceValue = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
        let countResultBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.size, options: .storageModeShared)!
        
        if let finalSum = analysisCommandBuffer.makeComputeCommandEncoder() {
            //setup pipeline state
            finalSum.setComputePipelineState(finalSumPipelineState)
            
            //setup  buffers
            var partialLengthStruct = PartialBufferLength(length: partialBufferLength)
        
            let arrayLength = metalDevice.makeBuffer(bytes: &partialLengthStruct,length: MemoryLayout<PartialBufferLength>.size,options: .storageModeShared)
            
            finalSum.setBuffer(partialBuffer, offset: 0, index: 0)
            finalSum.setBuffer(luminanceValue, offset: 0, index: 1)
            finalSum.setBuffer(arrayLength, offset: 0, index: 2)
            finalSum.setBuffer(countResultBuffer, offset: 0, index: 3)
            
            finalSum.dispatchThreadgroups(MTLSizeMake(1, 1, 1),
                                                  threadsPerThreadgroup: MTLSizeMake(partialBufferLength, 1, 1))
             
            finalSum.endEncoding()
            
           
        }
        
    }
    var latestResult = 0.0
    
    override func writeToBuffers() {
        let resultBuffer = luminanceValue?.contents().bindMemory(to: Float.self, capacity: 0)
        self.latestResult = Double(resultBuffer?.pointee ?? 0.0) / Double((getSelectedArea().width * getSelectedArea().height))
        
        if let zBuffer = result {
            zBuffer.append(latestResult)
        }
    }
    
    func luminanceFinalValue() -> Double{
        return self.resultBuffer
    }
    
    
    func calculateThreadSize(selectedWidth: Int, selectedHeight: Int) -> (threadGroupSize: MTLSize, gridSize: MTLSize, numOfThreadGroups: Int) {
       
         //0.003
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
         // Dispatch the compute shader with the size of the selected bounding box
         let threadgroupsX = (selectedWidth + threadGroupSize.width - 1) / threadGroupSize.width;
         let threadgroupsY = (selectedHeight + threadGroupSize.height - 1) / threadGroupSize.height;
         let _gridSize = MTLSize(width: threadgroupsX, height: threadgroupsY, depth: 1)
        let _numThreadSize = (_gridSize.width * _gridSize.height)
        
        return (threadGroupSize: threadGroupSize, gridSize: _gridSize, numOfThreadGroups: _numThreadSize )
         
    }
    
    struct PartialBufferLength {
        var length : Int
    }
    
}
