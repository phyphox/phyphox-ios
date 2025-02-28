//
//  HSVAnalyser.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 11.09.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

@available(iOS 14.0, *)
class HSVAnalyser: AnalysingModule {
    
    var svPipeLineState: MTLComputePipelineState?
    var hPipeLineState: MTLComputePipelineState?
    var finalSumPipelineState: MTLComputePipelineState?
    
    var result: DataBuffer?
    var mode: HSV_Mode
    
    var isValueY: Bool = true
    
    var value : MTLBuffer?
    var valueY : MTLBuffer?
    var valueX : MTLBuffer?
    var partialBufferForAnalysis : MTLBuffer?
    var partialBuffer_ : MTLBuffer?
    var numTHreadGroups : Int?
    
    var latestResult = 0.0
    
    init(result: DataBuffer?, mode: HSV_Mode) {
        self.result = result
        self.mode = mode
    }
    
    override func loadMetal(){
        
        guard let metalDevice = AnalysingModule.metalDevice else { return }
        let gpuFunctionLibrary = AnalysingModule.gpuFunctionLibrary
        
        let svFunction = gpuFunctionLibrary?.makeFunction(name: "computeSaturationAndValue")
        do {
            svPipeLineState = try metalDevice.makeComputePipelineState(function: svFunction!)
            
        } catch {
            print("Failed to create pipeline analysis state, er ror \(error)")
        }
        
        let hFunction = gpuFunctionLibrary?.makeFunction(name: "computeHue")
        do {
            hPipeLineState = try metalDevice.makeComputePipelineState(function: hFunction!)
            
        } catch {
            print("Failed to create pipeline analysis state, er ror \(error)")
        }
        
        let finalSum = gpuFunctionLibrary?.makeFunction(name: "computeFinalSum")
        do {
            finalSumPipelineState = try metalDevice.makeComputePipelineState(function: finalSum!)
        } catch  {
            print("Failed to create pipeline final sum state, error \(error)")
        }
    }
    
    override func doUpdate(metalCommandBuffer: MTLCommandBuffer,
                         cameraImageTextureY: MTLTexture,
                         cameraImageTextureCbCr: MTLTexture ){
        
        if(mode == .Hue){
            
            analyseHue( analysisCommandBuffer: metalCommandBuffer,
                        cameraImageTextureY: cameraImageTextureY,
                        cameraImageTextureCbCr: cameraImageTextureCbCr)
        } else {
            
            analyse(analysisCommandBuffer: metalCommandBuffer,
                    cameraImageTextureY: cameraImageTextureY,
                    cameraImageTextureCbCr: cameraImageTextureCbCr)
        }
        
        
    }
    
    var partialBuffer: MTLBuffer?
    
    func analyseHue(analysisCommandBuffer: MTLCommandBuffer,cameraImageTextureY: MTLTexture,cameraImageTextureCbCr: MTLTexture){
        
        guard let metalDevice = AnalysingModule.metalDevice else { return }
        
        guard let hPipeLineState = self.hPipeLineState else { return }
        
        guard let finalSumPipelineState = self.finalSumPipelineState else { return }
        
        let partialBufferLength = getNumOfThreadsGroups()
        var partialLengthStruct = PartialBufferLength(length: partialBufferLength * 2) // to get buffer of both x and y axis
        
        guard let partialArrayLength = metalDevice.makeBuffer(bytes: &partialLengthStruct,length: MemoryLayout<PartialBufferLength>.size ,options: .storageModeShared) else {
            return
        }
        
        if let hueAnalysisEndoding = analysisCommandBuffer.makeComputeCommandEncoder() {
            
            hueAnalysisEndoding.setComputePipelineState(hPipeLineState)
            
            partialBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride * partialBufferLength * 2 ,options: .storageModeShared)
            
            guard let selectionBuffer =
                    metalDevice.makeBuffer(bytes: &selectionState,length: MemoryLayout<SelectionState>.size,options: .storageModeShared) else {
                return
            }
            
            hueAnalysisEndoding.setTexture(cameraImageTextureY, index: 0)
            hueAnalysisEndoding.setTexture(cameraImageTextureCbCr, index: 1)
            hueAnalysisEndoding.setBuffer(partialBuffer, offset: 0, index: 0)
            hueAnalysisEndoding.setBuffer(selectionBuffer, offset: 0, index: 1)
            hueAnalysisEndoding.setBuffer(partialArrayLength, offset: 0, index: 2)
            
            hueAnalysisEndoding.dispatchThreadgroups(getCalcultedGridSize(),threadsPerThreadgroup: getCalculatedThreadGroupSize())
            
            hueAnalysisEndoding.endEncoding()
            
        }
        
        valueY = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)
        
        if let sumFinalYEncoding = analysisCommandBuffer.makeComputeCommandEncoder() {
            sumFinalYEncoding.setComputePipelineState(finalSumPipelineState)
            
            
            sumFinalYEncoding.setBuffer(partialBuffer, offset: 0, index: 0)
            sumFinalYEncoding.setBuffer(valueY, offset: 0, index: 1)
            sumFinalYEncoding.setBuffer(partialArrayLength, offset: 0, index: 2)
            
            sumFinalYEncoding.dispatchThreadgroups(MTLSizeMake(1, 1, 1),
                                                  threadsPerThreadgroup: MTLSizeMake(getNumOfThreadsGroups(), 1, 1))
            
            sumFinalYEncoding.endEncoding()
        }
        
        valueX = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)
        
        
        if let sumFinalXEncoding = analysisCommandBuffer.makeComputeCommandEncoder() {
            
            sumFinalXEncoding.setComputePipelineState(finalSumPipelineState)
            
            sumFinalXEncoding.setBuffer(partialBuffer, offset: getNumOfThreadsGroups() * MemoryLayout<Float>.stride, index: 0)
            sumFinalXEncoding.setBuffer(valueX, offset: 0, index: 1)
            sumFinalXEncoding.setBuffer(partialArrayLength, offset: 0 , index: 2)
            
            sumFinalXEncoding.dispatchThreadgroups(MTLSizeMake(1, 1, 1),
                                                   threadsPerThreadgroup: MTLSizeMake(getNumOfThreadsGroups() * 2, 1, 1))
            
            sumFinalXEncoding.endEncoding()
        }
        
    }
    
    func analyse(analysisCommandBuffer: MTLCommandBuffer,cameraImageTextureY: MTLTexture,cameraImageTextureCbCr: MTLTexture){
        
        guard let metalDevice = AnalysingModule.metalDevice else { return }
        
        guard let svPipeLineState = self.svPipeLineState else { return }
        
        guard let finalSumPipelineState = self.finalSumPipelineState else { return }
        
        let partialBufferLength = getNumOfThreadsGroups()
        
        var hsvMode = getHSVMode()
        
        if let analysisEncoding = analysisCommandBuffer.makeComputeCommandEncoder() {
            
            // MARK: analyse and get partial arrays of the analysis
            
            analysisEncoding.setComputePipelineState(svPipeLineState)
            
            guard let selectionBuffer = metalDevice.makeBuffer(bytes: &selectionState,length: MemoryLayout<SelectionState>.size,options: .storageModeShared) else {
            return
            }
            guard let partialBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride * partialBufferLength,options: .storageModeShared) else {
            return
            }
            guard let modeBuffer = metalDevice.makeBuffer(bytes: &hsvMode, length: MemoryLayout<Mode_HSV>.size * 4, options: .storageModeShared) else {
            return
            }
            
            analysisEncoding.setTexture(cameraImageTextureY, index: 0)
            analysisEncoding.setTexture(cameraImageTextureCbCr, index: 1)
            analysisEncoding.setBuffer(partialBuffer, offset: 0, index: 0)
            analysisEncoding.setBuffer(selectionBuffer, offset: 0, index: 1)
            analysisEncoding.setBuffer(modeBuffer, offset: 0, index: 2)
            
            analysisEncoding.dispatchThreadgroups(getCalcultedGridSize(),threadsPerThreadgroup: getCalculatedThreadGroupSize())
            
            
            // MARK: Reduce partial sum to single result
            
            analysisEncoding.setComputePipelineState(finalSumPipelineState)
            
            var partialLengthStruct = PartialBufferLength(length: partialBufferLength)
            
            value = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)
            
            guard let arrayLength = metalDevice.makeBuffer(bytes: &partialLengthStruct,length: MemoryLayout<PartialBufferLength>.size,options: .storageModeShared) else {
            return
            }
            
            analysisEncoding.setBuffer(partialBuffer, offset: 0, index: 0)
            analysisEncoding.setBuffer(value, offset: 0, index: 1)
            analysisEncoding.setBuffer(arrayLength, offset: 0, index: 2)
            
            analysisEncoding.dispatchThreadgroups(MTLSizeMake(1, 1, 1),
                                         threadsPerThreadgroup: MTLSizeMake(getNumOfThreadsGroups(), 1, 1))
            
            analysisEncoding.endEncoding()
            
        }
        
    }

    
    func getHSVMode() -> Float{
        
        if(mode == .Hue){
            return 0.0
        } else if(mode == .Saturation){
            return 1.0
        }else{
            return 2.0
        }
    }
    
    
    func getCalcultedGridSize() -> MTLSize{
        return calculateThreadSize(selectedWidth: getSelectedArea().width, selectedHeight: getSelectedArea().height).gridSize
    }
    
    func getCalculatedThreadGroupSize() -> MTLSize {
        return calculateThreadSize(selectedWidth: getSelectedArea().width, selectedHeight: getSelectedArea().height).threadGroupSize
    }
    
    func getNumOfThreadsGroups() -> Int {
        return calculateThreadSize(selectedWidth: getSelectedArea().width, selectedHeight: getSelectedArea().height).numOfThreadGroups
    }
    
    
    
    override func writeToBuffers() {
        
        /**
         let partialBufferContent = partialBuffer?.contents().bindMemory(to: Float.self, capacity: 0)
         let partialBufferArray = Array(UnsafeBufferPointer(start: partialBufferContent, count: getNumOfThreadsGroups() * 2))
         for (index, partialArray) in partialBufferArray.enumerated() {
         print("partialArrays content- index \(index) : ", partialArray)
         }
         */
        
        if(mode == .Hue){
            
            let resultYBuffer = valueY?.contents().bindMemory(to: Float.self, capacity: 0)
            let resultXBuffer = valueX?.contents().bindMemory(to: Float.self, capacity: 0)
            
            let averageHueRadians =  Double(atan2(resultYBuffer?.pointee ?? 0.0, resultXBuffer!.pointee))
            
            var averageHueDegrees = averageHueRadians * 180.0 / Double.pi;
            
            if (averageHueDegrees < 0) {
                averageHueDegrees += 360.0;  // Ensure the hue is positive
            }
            
            self.latestResult = averageHueDegrees
            
        } else {
            
            let resultBuffer = value?.contents().bindMemory(to: Float.self, capacity: 0)
            self.latestResult = Double(resultBuffer?.pointee ?? 0) / Double((getSelectedArea().width * getSelectedArea().height))
        }
        
        if let zBuffer = result {
            zBuffer.append(latestResult)
        }
        
    }
    
    
    var hueBuffer :  Float = 0.0
    
    func hueFinalValue() -> Float{
        return self.hueBuffer
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
    
    struct Mode_HSV {
        var mode : Float // 0.0 for Hue, 1.0 for Staturation, 2.0 for Value
        
    }
  
    enum HSV_Mode {
        case Hue
        case Saturation
        case Value
    }
    
    
}
