//
//  ExposureAnalyzer.swift
//  phyphox
//
//  Created by Sebastian Staacks on 10.03.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

@available(iOS 14.0, *)
class ExposureAnalyzer : AnalyzingModule {
    
    var lumaAnalysisPipelineState : MTLComputePipelineState?
    var minMaxRGBAnalysisPipelineState : MTLComputePipelineState?
    var finalSumPipelineState : MTLComputePipelineState?
    var finalMinMaxPipelineState : MTLComputePipelineState?
    
    var minMaxStruct: MinMax = MinMax(min: .nan, max: .nan)
    var lumaValue : MTLBuffer?
    var minMaxValue : MTLBuffer?
    
    var meanLuma: Double = .nan
    var maxRGB: Double = .nan
    var minRGB: Double = .nan
    
    override func loadMetal(){
        
        guard let metalDevice = AnalyzingModule.metalDevice else { return }
        let gpuFunctionLibrary = AnalyzingModule.gpuFunctionLibrary
        
        let lumaFunction = gpuFunctionLibrary?.makeFunction(name: "computeLuma")
        do {
            lumaAnalysisPipelineState = try metalDevice.makeComputePipelineState(function: lumaFunction!)
            
        } catch {
          print("Failed to create luma pipeline analysis state, error \(error)")
        }
        
        let minmaxRGBFunction = gpuFunctionLibrary?.makeFunction(name: "computeMinMaxRGB")
        do {
            minMaxRGBAnalysisPipelineState = try metalDevice.makeComputePipelineState(function: minmaxRGBFunction!)
            
        } catch {
          print("Failed to create minmaxRGB pipeline analysis state, error \(error)")
        }
        
        let finalSum = gpuFunctionLibrary?.makeFunction(name: "computeFinalSum")
        do {
            finalSumPipelineState = try metalDevice.makeComputePipelineState(function: finalSum!)
        } catch  {
            print("Failed to create pipeline final sum state, error \(error)")
        }
        
        let finalMinMax = gpuFunctionLibrary?.makeFunction(name: "computeFinalMinMax")
        do {
            finalMinMaxPipelineState = try metalDevice.makeComputePipelineState(function: finalMinMax!)
        } catch  {
            print("Failed to create pipeline final sum state, error \(error)")
        }
        
    }
    
    
    override func doUpdate(metalCommandBuffer: MTLCommandBuffer,
                         cameraImageTextureY: MTLTexture,
                         cameraImageTextureCbCr: MTLTexture){
               
        if let analysisEncoding = metalCommandBuffer.makeComputeCommandEncoder() {
            analyze(analysisEncoding: analysisEncoding,
                    analysisCommandBuffer: metalCommandBuffer,
                    cameraImageTextureY: cameraImageTextureY,
                    cameraImageTextureCbCr: cameraImageTextureCbCr)
        }
        
    }
    
    
    func analyze(analysisEncoding : MTLComputeCommandEncoder,
                 analysisCommandBuffer: MTLCommandBuffer,
                 cameraImageTextureY: MTLTexture?,
                 cameraImageTextureCbCr: MTLTexture?) {
        
        guard let metalDevice = AnalyzingModule.metalDevice else { return }
        
        guard let lumaAnalysPipelineState = self.lumaAnalysisPipelineState else {
            print("Failed to create lumaAnalysisPipelineState")
            return
        }
        
        guard let minMaxRGBAnalysPipelineState = self.minMaxRGBAnalysisPipelineState else {
            print("Failed to create minMaxRGBAnalysisPipelineState")
            return
        }
        
        guard let finalSumPipelineState = self.finalSumPipelineState else {
            print("Failed to create finalSumPipelineState")
            return
        }
        
        guard let finalMinMaxPipelineState = self.finalMinMaxPipelineState else {
            print("Failed to create finalMinMaxPipelineState")
            return
        }
        
        //setup pipeline
        analysisEncoding.setComputePipelineState(lumaAnalysPipelineState)
        
        let calculatedGridAndGroupSize = calculateThreadSize(selectedWidth: getSelectedArea().width,
                                                             selectedHeight: getSelectedArea().height)
        let numThreadGroups = calculatedGridAndGroupSize.numOfThreadGroups
        
        //setup buffers
        let selectionBuffer = metalDevice.makeBuffer(bytes: &selectionState,length: MemoryLayout<SelectionState>.size,options: .storageModeShared)
        let partialBuffer = metalDevice.makeBuffer(length: MemoryLayout<Int>.stride * numThreadGroups,options: .storageModeShared)!
        let partialMinBuffer = metalDevice.makeBuffer(length: MemoryLayout<Int>.stride * numThreadGroups,options: .storageModeShared)!
        let partialMaxBuffer = metalDevice.makeBuffer(length: MemoryLayout<Int>.stride * numThreadGroups,options: .storageModeShared)!
        var partialLengthStruct = PartialBufferLength(length: numThreadGroups)
        let arrayLength = metalDevice.makeBuffer(bytes: &partialLengthStruct,length: MemoryLayout<PartialBufferLength>.size,options: .storageModeShared)
               
        analysisEncoding.setTexture(cameraImageTextureY, index: 0)
        analysisEncoding.setBuffer(partialBuffer, offset: 0, index: 0)
        analysisEncoding.setBuffer(selectionBuffer, offset: 0, index: 1)
        analysisEncoding.setBuffer(arrayLength, offset: 0, index: 2)
        
        // dispatch it
        analysisEncoding.dispatchThreadgroups(calculatedGridAndGroupSize.gridSize,
                                              threadsPerThreadgroup: calculatedGridAndGroupSize.threadGroupSize)
            
        
        lumaValue = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
        
        //setup pipeline state
        analysisEncoding.setComputePipelineState(finalSumPipelineState)
        
        analysisEncoding.setBuffer(partialBuffer, offset: 0, index: 0)
        analysisEncoding.setBuffer(lumaValue, offset: 0, index: 1)
        analysisEncoding.setBuffer(arrayLength, offset: 0, index: 2)
        
        analysisEncoding.dispatchThreadgroups(MTLSizeMake(1, 1, 1),
                                              threadsPerThreadgroup: MTLSizeMake(256, 1, 1))
         
        // Min max RGB calculation
        
        analysisEncoding.setComputePipelineState(minMaxRGBAnalysPipelineState)

        analysisEncoding.setTexture(cameraImageTextureY, index: 0)
        analysisEncoding.setTexture(cameraImageTextureCbCr, index: 1)
        
        analysisEncoding.setBuffer(partialMinBuffer, offset: 0, index: 0)
        analysisEncoding.setBuffer(partialMaxBuffer, offset: 0, index: 1)
        analysisEncoding.setBuffer(selectionBuffer, offset: 0, index: 2)
        analysisEncoding.setBuffer(arrayLength, offset: 0, index: 3)
        
        analysisEncoding.dispatchThreadgroups(calculatedGridAndGroupSize.gridSize,
                                              threadsPerThreadgroup: calculatedGridAndGroupSize.threadGroupSize)
        
        minMaxValue = metalDevice.makeBuffer(length: MemoryLayout<MinMax>.stride, options: .storageModeShared)!
        
        analysisEncoding.setComputePipelineState(finalMinMaxPipelineState)
        
        analysisEncoding.setBuffer(partialMinBuffer, offset: 0, index: 0)
        analysisEncoding.setBuffer(partialMaxBuffer, offset: 0, index: 1)
        analysisEncoding.setBuffer(minMaxValue, offset: 0, index: 2)
        analysisEncoding.setBuffer(arrayLength, offset: 0, index: 3)
        
        analysisEncoding.dispatchThreadgroups(MTLSizeMake(1, 1, 1),
                                              threadsPerThreadgroup: MTLSizeMake(256, 1, 1))
        
        analysisEncoding.endEncoding()
        
    }
    
    override func prepareWriteToBuffers(cameraSettings: CameraSettingsModel) {
        let lumaResultBuffer = lumaValue?.contents().bindMemory(to: Float.self, capacity: 0)
        meanLuma = Double(lumaResultBuffer?.pointee ?? 0.0) / Double((getSelectedArea().width * getSelectedArea().height))
        let minMaxResultBuffer = minMaxValue?.contents().bindMemory(to: MinMax.self, capacity: 0)
        minRGB = Double(minMaxResultBuffer?.pointee.min ?? .nan)
        maxRGB = Double(minMaxResultBuffer?.pointee.max ?? .nan)
    }
    
    override func writeToBuffers() {
        // This analyzer is only used internally for auto exposure and does not write to experiment data containers
    }
    
    func reset() {
        meanLuma = .nan
        maxRGB = .nan
        minRGB = .nan
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
