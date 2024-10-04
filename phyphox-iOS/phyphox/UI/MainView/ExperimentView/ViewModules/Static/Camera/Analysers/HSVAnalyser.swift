//
//  HSVAnalyser.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 11.09.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

@available(iOS 13.0, *)
class HSVAnalyser: AnalysingModule {
    
    var svPipeLineState: MTLComputePipelineState?
    var hPipeLineState: MTLComputePipelineState?
    var finalSumPipelineState: MTLComputePipelineState?
    var selectionState = MetalRenderer.SelectionStruct(x1: 0.4, x2: 0.6, y1: 0.4, y2: 0.6, editable: false)
    
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
    
    override func update(selectionArea: MetalRenderer.SelectionStruct,
                         metalCommandBuffer: MTLCommandBuffer,
                         cameraImageTextureY: MTLTexture,
                         cameraImageTextureCbCr: MTLTexture ){
        
        self.selectionState = selectionArea
        
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
                    metalDevice.makeBuffer(bytes: &selectionState,length: MemoryLayout<MetalRenderer.SelectionStruct>.size,options: .storageModeShared) else {
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
            
            guard let selectionBuffer = metalDevice.makeBuffer(bytes: &selectionState,length: MemoryLayout<MetalRenderer.SelectionStruct>.size,options: .storageModeShared) else {
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
    
    
    /**
     func analyse(analysisCommandBuffer: MTLCommandBuffer,cameraImageTextureY: MTLTexture,cameraImageTextureCbCr: MTLTexture){
     
     guard let metalDevice = AnalysingModule.metalDevice else { return }
     
     guard let svPipeLineState = self.svPipeLineState else { return }
     
     guard let finalSumPipelineState = self.finalSumPipelineState else { return }
     
     let partialBufferLength = getNumOfThreadsGroups()
     
     var hsvMode = getHSVMode()
     
     var buffers: BuffersHSV
     
     var texture: Textures
     
     var reductionBuffers: BuffersForReduction
     
     if let analysisEncoding = analysisCommandBuffer.makeComputeCommandEncoder() {
     
     analysisEncoding.setComputePipelineState(svPipeLineState)
     
     guard let selectionBuffer = metalDevice.makeBuffer(bytes: &selectionState,length: MemoryLayout<MetalRenderer.SelectionStruct>.size,options: .storageModeShared) else {
     return
     }
     guard let partialBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride * partialBufferLength,options: .storageModeShared) else {
     return
     }
     guard let modeBuffer = metalDevice.makeBuffer(bytes: &hsvMode, length: MemoryLayout<Mode_HSV>.size * 4, options: .storageModeShared) else {
     return
     }
     
     buffers = BuffersHSV(partialBuffer: partialBuffer, selectionBuffer: selectionBuffer, modeBuffer: modeBuffer)
     texture = Textures(textureY: cameraImageTextureY, textureCbCr: cameraImageTextureCbCr)
     
     encodeAndDispatchBuffers(encoder: analysisEncoding, textures: texture, buffers: buffers)
     
     analysisEncoding.setComputePipelineState(finalSumPipelineState)
     
     //setup  buffers
     var partialLengthStruct = PartialBufferLength(length: partialBufferLength)
     
     guard let value = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared) else { return }
     
     guard let arrayLength = metalDevice.makeBuffer(bytes: &partialLengthStruct,length: MemoryLayout<PartialBufferLength>.size,options: .storageModeShared) else {
     return
     }
     
     reductionBuffers = BuffersForReduction(partialBuffer: partialBuffer, finalValue: value, partialBufferLength: arrayLength)
     
     computeFinalSumAndDispatch(encoder: analysisEncoding, buffers: reductionBuffers)
     
     }
     
     
     guard let value = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared) else {
     return
     }
     
     if let finalSum = analysisCommandBuffer.makeComputeCommandEncoder() {
     //setup pipeline state
     finalSum.setComputePipelineState(finalSumPipelineState)
     
     //setup  buffers
     var partialLengthStruct = PartialBufferLength(length: partialBufferLength)
     
     guard let arrayLength = metalDevice.makeBuffer(bytes: &partialLengthStruct,length: MemoryLayout<PartialBufferLength>.size,options: .storageModeShared) else {
     return
     }
     
     reductionBuffers = BuffersForReduction(partialBuffer: buffers.partialBuffer, finalValue: value, partialBufferLength: arrayLength)
     
     computeFinalSumAndDispatch(encoder: finalSum, buffers: reductionBuffers)
     }
     
     if( mode == .Hue){
     guard let analysisEncdoing_ = analysisCommandBuffer.makeComputeCommandEncoder() else  {
     return
     }
     analysisEncdoing_.setComputePipelineState(svPipeLineState)
     
     guard let partialBufferForHueX = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride * partialBufferLength,options: .storageModeShared) else {
     return
     }
     
     buffers.partialBuffer = partialBufferForHueX
     
     encodeAndDispatchBuffers(encoder: analysisEncdoing_, textures: texture, buffers: buffers)
     
     
     
     }
     
     guard let finalResult_ = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared) else {
     return
     }
     
     if let finalSum = analysisCommandBuffer.makeComputeCommandEncoder() {
     
     finalSum.setComputePipelineState(finalSumPipelineState)
     
     reductionBuffers.partialBuffer = buffers.partialBuffer
     reductionBuffers.finalValue = finalResult_
     
     computeFinalSumAndDispatch(encoder: finalSum, buffers: reductionBuffers)
     
     }
     
     }
     */
    
    func encodeAndDispatchBuffers(encoder: MTLComputeCommandEncoder, textures: Textures ,buffers: BuffersHSV) {
        
        encoder.setTexture(textures.textureY, index: 0)
        encoder.setTexture(textures.textureCbCr, index: 1)
        encoder.setBuffer(buffers.partialBuffer, offset: 0, index: 0)
        encoder.setBuffer(buffers.selectionBuffer, offset: 0, index: 1)
        encoder.setBuffer(buffers.modeBuffer, offset: 0, index: 2)
        
        encoder.dispatchThreadgroups(getCalcultedGridSize(),threadsPerThreadgroup: getCalculatedThreadGroupSize())
        
    }
    
    func encodeAndDispatchHueBuffers(encoder: MTLComputeCommandEncoder, textures: Textures ,buffers: HueBufferDescriptor) {
        
        encoder.setTexture(textures.textureY, index: 0)
        encoder.setTexture(textures.textureCbCr, index: 1)
        encoder.setBuffer(buffers.partialBuffer, offset: 0, index: 0)
        encoder.setBuffer(buffers.selectionBuffer, offset: 0, index: 1)
        encoder.setBuffer(buffers.partialBufferLength, offset: 0, index: 2)
        
        encoder.dispatchThreadgroups(getCalcultedGridSize(),threadsPerThreadgroup: getCalculatedThreadGroupSize())
        
        
    }
    
    
    func computeFinalSumAndDispatch(encoder: MTLComputeCommandEncoder, buffers: BuffersForReduction){
        
        encoder.setBuffer(buffers.partialBuffer, offset: 0, index: 0)
        encoder.setBuffer(buffers.finalValue, offset: 0, index: 1)
        encoder.setBuffer(buffers.partialBufferLength, offset: 0, index: 2)
        
        
        encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1),
                                     threadsPerThreadgroup: MTLSizeMake(getNumOfThreadsGroups(), 1, 1))
        
        
        
    }
    
    func computeFinalSumAndDispatchWithOffset(encoder: MTLComputeCommandEncoder, buffers: BuffersForReduction){
        
        encoder.setBuffer(buffers.partialBuffer, offset: 0, index: 0)
        encoder.setBuffer(buffers.finalValue, offset: 0, index: 1)
        encoder.setBuffer(buffers.partialBufferLength, offset: getNumOfThreadsGroups() , index: 2)
        
        
        encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1),
                                     threadsPerThreadgroup: MTLSizeMake(getNumOfThreadsGroups() * 2, 1, 1))
        
        encoder.endEncoding()
        
        
    }
    
    func getHSVMode() -> Float{
        
        var inputMode = Mode(enumValue: mode)
        
        if(inputMode.enumValue == .Hue){
            return 0.0
        } else if(inputMode.enumValue == .Saturation){
            return 1.0
        }else{
            return 2.0
        }
    }
    
    
    struct Textures{
        var textureY: MTLTexture
        var textureCbCr: MTLTexture
    }
    
    struct BuffersHSV{
        var partialBuffer: MTLBuffer
        var selectionBuffer: MTLBuffer
        var modeBuffer: MTLBuffer
    }
    
    struct HueBufferDescriptor {
        var partialBuffer: MTLBuffer
        var selectionBuffer: MTLBuffer
        var partialBufferLength: MTLBuffer
    }
    
    struct BuffersForReduction {
        var partialBuffer: MTLBuffer
        var finalValue: MTLBuffer
        var partialBufferLength: MTLBuffer
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
    
    
    /**
     override func writeToBuffers() {
     
     let resultBuffer = value?.contents().bindMemory(to: Float.self, capacity: 0)
     
     let partialBufferValue = partialBufferForAnalysis?.contents().bindMemory(to: Float.self, capacity: 0)
     
     print("partialBuffer: ", partialBufferValue?.pointee)
     
     // let partialBufferArray = Array(UnsafeBufferPointer(start: partialBufferValue, count: numTHreadGroups ?? 0))
     
     print("resultBuffer" , resultBuffer?.pointee)
     
     self.latestResult = Double(resultBuffer?.pointee ?? 0)
     
     if let xBuffer = value_{
     let xValue = xBuffer.contents().bindMemory(to: Float.self, capacity: 0)
     print("xBuffer" , xValue.pointee)
     
     let partialBufferValue_ = partialBuffer_?.contents().bindMemory(to: Float.self, capacity: 0)
     
     print("partialBuffer___: ", partialBufferValue_?.pointee)
     
     
     let averageHueRadians =  Double(atan2(resultBuffer?.pointee ?? 0.0, xValue.pointee))
     // Convert the average hue back to degrees
     var averageHueDegrees = averageHueRadians * 180.0 / Double.pi;
     
     if (averageHueDegrees < 0) {
     averageHueDegrees += 360.0;  // Ensure the hue is positive
     }
     
     self.latestResult = averageHueDegrees
     }
     
     if(mode != .Hue ){
     self.latestResult = Double(resultBuffer?.pointee ?? 0) / Double((getSelectedArea().width * getSelectedArea().height))
     }
     
     if let zBuffer = result {
     zBuffer.append(latestResult)
     }
     }
     */
    
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
    
    func getSelectedArea() -> (width: Int, height: Int){
        //setup the thread group size and grid size
        let _width = Int((selectionState.x2 - selectionState.x1 + 1))
        let _height = Int((selectionState.y2 - selectionState.y1 + 1))
        
        return (width: _width, height: _height)
    }
    
    
    struct PartialBufferLength {
        var length : Int
    }
    
    struct Mode_HSV {
        var mode : Float // 0.0 for Hue, 1.0 for Staturation, 2.0 for Value
        
    }
    
    struct HueValue {
        var isY: Bool // else isX
    }
    
    enum HSV_Mode {
        case Hue
        case Saturation
        case Value
    }
    
    struct Mode {
        var enumValue: HSV_Mode
    }
    
}
