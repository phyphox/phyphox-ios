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
    
    var isValueY: Bool = true
    
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
    var value_ : MTLBuffer?
    var partialBuffer : MTLBuffer?
    var partialBuffer_ : MTLBuffer?
    var numTHreadGroups : Int?
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
        
        
        //let hueBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
        //let saturationBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
        //let valueBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
        
        var hsvMode: Float
        var inputMode = Mode(enumValue: mode)
        
        print("mode: ", inputMode.enumValue)
        
        if(inputMode.enumValue == .Hue){
            hsvMode = 0.0
        } else if(inputMode.enumValue == .Saturation){
            hsvMode = 1.0
        }else{
            hsvMode = 2.0
        }
        
        let calculatedGridAndGroupSize = calculateThreadSize(selectedWidth: getSelectedArea().width, selectedHeight: getSelectedArea().height)
        
        let partialBufferLength = calculatedGridAndGroupSize.numOfThreadGroups
        numTHreadGroups = partialBufferLength
        //setup buffers
        let selectionBuffer = metalDevice.makeBuffer(bytes: &selectionState,length: MemoryLayout<MetalRenderer.SelectionStruct>.size,options: .storageModeShared)
        partialBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride * partialBufferLength,options: .storageModeShared)!
        let modeBuffer = metalDevice.makeBuffer(bytes: &hsvMode, length: MemoryLayout<Mode_HSV>.size * 4, options: .storageModeShared)
        
        print("memory mode length: ",MemoryLayout<Mode>.size)
        
        var hsvYvalue : HueValue = HueValue(isY: true)
        
        let hueValue = metalDevice.makeBuffer(bytes: &hsvYvalue,length: MemoryLayout<HueValue>.size,options: .storageModeShared)
        
        analyseEncoding.setTexture(cameraImageTextureY, index: 0)
        analyseEncoding.setTexture(cameraImageTextureCbCr, index: 1)
        analyseEncoding.setBuffer(partialBuffer, offset: 0, index: 0)
        analyseEncoding.setBuffer(selectionBuffer, offset: 0, index: 1)
        analyseEncoding.setBuffer(modeBuffer, offset: 0, index: 2)
        analyseEncoding.setBuffer(hueValue, offset: 0, index: 3)
        
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
            
           
            if( inputMode.enumValue == .Hue){
                guard let analysisEncdoing_ = analysisCommandBuffer.makeComputeCommandEncoder() else  {
                    analyseEncoding.endEncoding()
                    return
                }
                analysisEncdoing_.setComputePipelineState(hsvPipeLineState)
                
                
                //let hueBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
                //let saturationBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
                //let valueBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
                
                var hsvMode_: Float = 0.0
               
                
                partialBuffer_ = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride * partialBufferLength,options: .storageModeShared)!
                let modeBuffer = metalDevice.makeBuffer(bytes: &hsvMode_, length: MemoryLayout<Mode_HSV>.size * 4, options: .storageModeShared)
                
                
                print("memory mode length: ",MemoryLayout<Mode>.size)
                
                var hsvYvalue_ : HueValue = HueValue(isY: false)
                
                let hueValue_ = metalDevice.makeBuffer(bytes: &hsvYvalue_,length: MemoryLayout<HueValue>.size,options: .storageModeShared)
                
                analysisEncdoing_.setTexture(cameraImageTextureY, index: 0)
                analysisEncdoing_.setTexture(cameraImageTextureCbCr, index: 1)
                analysisEncdoing_.setBuffer(partialBuffer_, offset: 0, index: 0)
                analysisEncdoing_.setBuffer(selectionBuffer, offset: 0, index: 1)
                analysisEncdoing_.setBuffer(modeBuffer, offset: 0, index: 2)
                analysisEncdoing_.setBuffer(hueValue_, offset: 0, index: 3)
                
                analysisEncdoing_.dispatchThreadgroups(calculatedGridAndGroupSize.gridSize,
                                                     threadsPerThreadgroup: calculatedGridAndGroupSize.threadGroupSize)
                
                analysisEncdoing_.endEncoding()
                
                value_ = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
                let countResultBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.size, options: .storageModeShared)!
                
                if let finalSum = analysisCommandBuffer.makeComputeCommandEncoder() {
                    //setup pipeline state
                    finalSum.setComputePipelineState(finalSumPipelineState)
                    
                    //setup  buffers
                    var partialLengthStruct = PartialBufferLength(length: partialBufferLength)
                    
                    let arrayLength = metalDevice.makeBuffer(bytes: &partialLengthStruct,length: MemoryLayout<PartialBufferLength>.size,options: .storageModeShared)
                    
                    finalSum.setBuffer(partialBuffer_, offset: 0, index: 0)
                    finalSum.setBuffer(value_, offset: 0, index: 1)
                    finalSum.setBuffer(arrayLength, offset: 0, index: 2)
                    finalSum.setBuffer(countResultBuffer, offset: 0, index: 3)
                    
                    finalSum.dispatchThreadgroups(MTLSizeMake(1, 1, 1),
                                                  threadsPerThreadgroup: MTLSizeMake(partialBufferLength, 1, 1))
                    
                    finalSum.endEncoding()
                    
                }
                   
            }
            
        }
        
    }
    
    var latestResult = 0.0
    
    override func writeToBuffers() {
        
        let resultBuffer = value?.contents().bindMemory(to: Float.self, capacity: 0)
        
        let partialBufferValue = partialBuffer?.contents().bindMemory(to: Float.self, capacity: 0)
        
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
    
    var hueBuffer :  Float = 0.0
    
    func hueFinalValue() -> Float{
        return self.hueBuffer
    }
    
    enum HSV_Mode: UInt8 {
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
    
    struct Mode_HSV {
        var mode : Float // 0.0 for Hue, 1.0 for Staturation, 2.0 for Value
            
    }
    
    struct HueValue {
        var isY: Bool
    }
    
}
