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
    
    var luminanceValue : MTLBuffer?
    
    var result: DataBuffer?
    var latestResult: Double = .nan
    
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
        
        let sizeOfSelectedPixel = getSelectedArea().width * getSelectedArea().height
        
        let pixelBytesPointer = UnsafeMutableRawPointer.allocate(byteCount: sizeOfSelectedPixel , alignment: 1)
        let pixelRegions = MTLRegionMake2D(0, getSelectedArea().height/2, getSelectedArea().width, 1)
        
        var pixelBuffer = [UInt8](repeating: 0, count: getSelectedArea().width)
        
        //cameraImageTextureY?.getBytes(pixelBytesPointer, bytesPerRow: <#T##Int#>, bytesPerImage: <#T##Int#>, from: pixelRegions, mipmapLevel: 0, slice: 0)
        cameraImageTextureY?.getBytes(&pixelBuffer, bytesPerRow: getSelectedArea().width, from: pixelRegions, mipmapLevel: 0)
        
        for (index_, yVal) in pixelBuffer.enumerated() {
            print("Pixel \(index_): Y + \(yVal)")
        }
                
        let calculatedGridAndGroupSize = calculateThreadSize(selectedWidth: getSelectedArea().width, selectedHeight: getSelectedArea().height)
        
        let partialBufferLength = calculatedGridAndGroupSize.numOfThreadGroups
        //setup buffers
        let selectionBuffer = metalDevice.makeBuffer(bytes: &selectionState, length: MemoryLayout<SelectionState>.size, options: .storageModeShared)
        let partialBuffer = metalDevice.makeBuffer(length: MemoryLayout<Int>.stride * partialBufferLength, options: .storageModeShared)!
        var partialLengthStruct = PartialBufferLength(length: partialBufferLength)
        let arrayLength = metalDevice.makeBuffer(bytes: &partialLengthStruct,length: MemoryLayout<PartialBufferLength>.size,options: .storageModeShared)
        
        analyzeEncoding.setTexture(cameraImageTextureY, index: 0)
        analyzeEncoding.setTexture(cameraImageTextureCbCr, index: 1)
        analyzeEncoding.setBuffer(partialBuffer, offset: 0, index: 0)
        analyzeEncoding.setBuffer(selectionBuffer, offset: 0, index: 1)
        analyzeEncoding.setBuffer(arrayLength, offset: 0, index: 2)
        
        analyzeEncoding.dispatchThreadgroups(calculatedGridAndGroupSize.gridSize,
                                             threadsPerThreadgroup: calculatedGridAndGroupSize.threadGroupSize)
                
        luminanceValue = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
        
        analyzeEncoding.setComputePipelineState(finalSumPipelineState)
        
        analyzeEncoding.setBuffer(partialBuffer, offset: 0, index: 0)
        analyzeEncoding.setBuffer(luminanceValue, offset: 0, index: 1)
        analyzeEncoding.setBuffer(arrayLength, offset: 0, index: 2)
        
        analyzeEncoding.dispatchThreadgroups(MTLSizeMake(1, 1, 1),
                                              threadsPerThreadgroup: MTLSizeMake(256, 1, 1))
         
        analyzeEncoding.endEncoding()
        
    }
    
    override func prepareWriteToBuffers(cameraSettings: CameraSettingsModel) {
        let resultBuffer = luminanceValue?.contents().bindMemory(to: Float.self, capacity: 0)
        let unscaledLuminance = Double(resultBuffer?.pointee ?? 0.0) / Double((getSelectedArea().width * getSelectedArea().height))
        latestResult = pow(2.0, Double(cameraSettings.currentApertureValue))/2.0 * 100.0/Double(cameraSettings.currentIso) * (1.0/60.0)/(Double(cameraSettings.currentShutterSpeed.value)/Double(cameraSettings.currentShutterSpeed.timescale)) * unscaledLuminance
    }
    
    override func writeToBuffers() {
        if let zBuffer = result {
            zBuffer.append(latestResult)
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
    
    struct PartialBufferLength {
        var length : Int
    }
    
}


/**
 
 func dumpYRegionFromTexture(device: MTLDevice,
                             commandQueue: MTLCommandQueue,
                             textureY: MTLTexture,
                             origin: MTLOrigin,
                             size: MTLSize) -> [UInt8]? {
     guard let lib = try? device.makeDefaultLibrary(bundle: .main),
           let function = lib.makeFunction(name: "readYTexture"),
           let pipeline = try? device.makeComputePipelineState(function: function) else {
         return nil
     }

     let regionWidth = size.width
     let regionHeight = size.height
     let bufferSize = regionWidth * regionHeight
     let outputBuffer = device.makeBuffer(length: bufferSize, options: .storageModeShared)!

     // Buffers for region origin and size
     let originBuffer = device.makeBuffer(bytes: [UInt32(origin.x), UInt32(origin.y)],
                                          length: MemoryLayout<simd_uint2>.stride,
                                          options: [])
     let sizeBuffer = device.makeBuffer(bytes: [UInt32(size.width), UInt32(size.height)],
                                        length: MemoryLayout<simd_uint2>.stride,
                                        options: [])

     let commandBuffer = commandQueue.makeCommandBuffer()!
     let encoder = commandBuffer.makeComputeCommandEncoder()!
     encoder.setComputePipelineState(pipeline)
     encoder.setTexture(textureY, index: 0)
     encoder.setBuffer(outputBuffer, offset: 0, index: 0)
     encoder.setBuffer(originBuffer, offset: 0, index: 1)
     encoder.setBuffer(sizeBuffer, offset: 0, index: 2)

     let threadGroupSize = MTLSizeMake(16, 16, 1)
     let threadGroups = MTLSize(width: (regionWidth + 15) / 16,
                                height: (regionHeight + 15) / 16,
                                depth: 1)

     encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
     encoder.endEncoding()
     commandBuffer.commit()
     commandBuffer.waitUntilCompleted()

     let rawPointer = outputBuffer.contents().bindMemory(to: UInt8.self, capacity: bufferSize)
     return Array(UnsafeBufferPointer(start: rawPointer, count: bufferSize))
 }
 
 let origin = MTLOrigin(x: 0, y: 377, z: 0) // start row
 let size = MTLSize(width: 1024, height: 1, depth: 1) // 1 row
 let yValues = dumpYRegionFromTexture(device: device,
                                      commandQueue: queue,
                                      textureY: texture,
                                      origin: origin,
                                      size: size)
 
 */
