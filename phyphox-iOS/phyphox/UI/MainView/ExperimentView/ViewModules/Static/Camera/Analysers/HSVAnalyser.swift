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
  
    var hsvPipeLineState: MTLComputePipelineState?
    var finalSumPipelineState: MTLComputePipelineState?
    var selectionState = MetalRenderer.SelectionStruct(x1: 0.4, x2: 0.6, y1: 0.4, y2: 0.6, editable: false)
    
    var result: DataBuffer?
    var mode: HSV_Mode
    
    init(result: DataBuffer?, mode: HSV_Mode) {
        self.result = result
        self.mode = mode
    }
    
    override func loadMetal(){
        
        guard let metalDevice = AnalysingModule.metalDevice else { return }
        let gpuFunctionLibrary = AnalysingModule.gpuFunctionLibrary
        
        let hsvFunction = gpuFunctionLibrary?.makeFunction(name: "computeHSV")
        do {
            hsvPipeLineState = try metalDevice.makeComputePipelineState(function: hsvFunction!)
            
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
        
        //checkTimeInterval(metalCommandBuffer: metalCommandBuffer)
        
        self.selectionState = selectionArea
       
        if let analysisEncoding = metalCommandBuffer.makeComputeCommandEncoder() {
            analyse(analyseEncoding : analysisEncoding, 
                    analysisCommandBuffer: metalCommandBuffer,
                    cameraImageTextureY: cameraImageTextureY,
                    cameraImageTextureCbCr: cameraImageTextureCbCr)
        }
        
    }
    var value : MTLBuffer?
    func analyse(analyseEncoding : MTLComputeCommandEncoder,
                 analysisCommandBuffer: MTLCommandBuffer,
                 cameraImageTextureY: MTLTexture,
                 cameraImageTextureCbCr: MTLTexture){
        
        guard let metalDevice = AnalysingModule.metalDevice else { return }
        
        
        guard let hsvPipeLineState = self.hsvPipeLineState else {
            print("Failed to create analysisPipelineState")
            analyseEncoding.endEncoding()
            return
        }
        
        guard let finalSumPipelineState = self.finalSumPipelineState else {
            print("Failed to create finalSumPipelineState")
            analyseEncoding.endEncoding()
            return
        }
        analyseEncoding.setComputePipelineState(hsvPipeLineState)
        
        
        let hueBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
        let saturationBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
        let valueBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
        
        var inputMode = Mode(enumValue: mode)
        
        let calculatedGridAndGroupSize = calculateThreadSize(selectedWidth: getSelectedArea().width, selectedHeight: getSelectedArea().height)
        
        let partialBufferLength = calculatedGridAndGroupSize.numOfThreadGroups
        //setup buffers
        let selectionBuffer = metalDevice.makeBuffer(bytes: &selectionState,length: MemoryLayout<MetalRenderer.SelectionStruct>.size,options: .storageModeShared)
        let partialBuffer = metalDevice.makeBuffer(length: MemoryLayout<Int>.stride * partialBufferLength,options: .storageModeShared)!
        let modeBuffer = metalDevice.makeBuffer(bytes: &inputMode, length: MemoryLayout<Mode>.size * 4, options: .storageModeShared)
        
        print("memory mode length: ",MemoryLayout<Mode>.size)
        
        analyseEncoding.setTexture(cameraImageTextureY, index: 0)
        analyseEncoding.setTexture(cameraImageTextureCbCr, index: 1)
        analyseEncoding.setBuffer(partialBuffer, offset: 0, index: 0)
        analyseEncoding.setBuffer(selectionBuffer, offset: 0, index: 1)
        analyseEncoding.setBuffer(modeBuffer, offset: 0, index: 2)
        
        analyseEncoding.dispatchThreadgroups(calculatedGridAndGroupSize.gridSize,
                                             threadsPerThreadgroup: calculatedGridAndGroupSize.threadGroupSize)
        
        analyseEncoding.endEncoding()
        
        value = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
        let countResultBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.size, options: .storageModeShared)!
        
        if let finalSum = analysisCommandBuffer.makeComputeCommandEncoder() {
            //setup pipeline state
            finalSum.setComputePipelineState(finalSumPipelineState)
            
            //setup  buffers
            var partialLengthStruct = PartialBufferLength(length: partialBufferLength)
        
            let arrayLength = metalDevice.makeBuffer(bytes: &partialLengthStruct,length: MemoryLayout<PartialBufferLength>.size,options: .storageModeShared)
            
            finalSum.setBuffer(partialBuffer, offset: 0, index: 0)
            finalSum.setBuffer(value, offset: 0, index: 1)
            finalSum.setBuffer(arrayLength, offset: 0, index: 2)
            finalSum.setBuffer(countResultBuffer, offset: 0, index: 3)
            
            finalSum.dispatchThreadgroups(MTLSizeMake(1, 1, 1),
                                                  threadsPerThreadgroup: MTLSizeMake(partialBufferLength, 1, 1))
             
            finalSum.endEncoding()
            
           
            let count = countResultBuffer.contents().bindMemory(to: Float.self, capacity: 1)
            
            print("countResultBuffer: ", count.pointee)
            
        }
        
    }
    
    var latestResult = 0.0
    
    override func writeToBuffers() {
        
        let resultBuffer = value?.contents().bindMemory(to: Float.self, capacity: 0)
    
        print("resultBuffer" , resultBuffer?.pointee)
        
        self.latestResult = Double(resultBuffer?.pointee ?? 0.0)
        
        if let zBuffer = result {
            zBuffer.append(latestResult)
        }
    }
    
    var hueBuffer :  Float = 0.0
    
    func hueFinalValue() -> Float{
        return self.hueBuffer
    }
    
    enum HSV_Mode: UInt32 {
        case Hue = 0
        case Saturation = 1
        case Value = 2
    }
    
    struct Mode {
        var enumValue: HSV_Mode
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
    
}
