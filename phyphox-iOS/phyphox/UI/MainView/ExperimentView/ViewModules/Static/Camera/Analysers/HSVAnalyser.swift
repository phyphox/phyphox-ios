//
//  HSVAnalyser.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 11.09.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

class HSVAnalyser {
    
    var metalDevice: MTLDevice
    var hsvPipeLineState: MTLComputePipelineState?
    var finalSumPipelineState: MTLComputePipelineState?
    
    init(metalDevice: MTLDevice) {
        self.metalDevice = metalDevice
    }
    
    func loadMetal(){
        let gpuFunctionLibrary = metalDevice.makeDefaultLibrary()
        
        let hsvFunction = gpuFunctionLibrary?.makeFunction(name: "computeHSV")
        do {
            hsvPipeLineState = try metalDevice.makeComputePipelineState(function: hsvFunction!)
            
        } catch {
          print("Failed to create pipeline analysis state, error \(error)")
        }
        
        let finalSum = gpuFunctionLibrary?.makeFunction(name: "computeFinalSum")
        do {
            finalSumPipelineState = try metalDevice.makeComputePipelineState(function: finalSum!)
        } catch  {
            print("Failed to create pipeline final sum state, error \(error)")
        }
    }
    
    @available(iOS 13.0, *)
    func update(texture: MTLTexture,
                selectionArea: MetalRenderer.SelectionStruct,
                metalCommandBuffer: MTLCommandBuffer){
        
        //checkTimeInterval(metalCommandBuffer: metalCommandBuffer)
        
        //self.selectionState = selectionArea
       
        
        if let analysisEncoding = metalCommandBuffer.makeComputeCommandEncoder() {
            //analyse(analysisEncoding: analysisEncoding, texture: texture, metalCommandBuffer: metalCommandBuffer)
        }
        
        
    }
    
    func analyse(analyseEncoding : MTLComputeCommandEncoder, analysisCommandBuffer: MTLCommandBuffer,
                 cameraImageTextureY: CVMetalTexture?, cameraImageTextureCbCr: CVMetalTexture? ){
        
        guard let cameraImageY = cameraImageTextureY, let cameraImageCbCr = cameraImageTextureCbCr else {
            analyseEncoding.endEncoding()
            return
        }
        
        guard let hsvPipeLineState = self.hsvPipeLineState else {
            print("Failed to create analysisPipelineState")
            return
        }
        
        guard let finalSumPipelineState = self.finalSumPipelineState else {
            print("Failed to create finalSumPipelineState")
            return
        }
        analyseEncoding.setComputePipelineState(hsvPipeLineState)
        
        
        let result = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
        let saturationBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
        let valueBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
        
        analyseEncoding.setTexture(CVMetalTextureGetTexture(cameraImageY), index: 0)
        analyseEncoding.setTexture(CVMetalTextureGetTexture(cameraImageCbCr), index: 1)
        analyseEncoding.setBuffer(result, offset: 0, index: 0)
        //analyseEncoding.setBuffer(saturationBuffer, offset: 0, index: 1)
        //analyseEncoding.setBuffer(valueBuffer, offset: 0, index: 2)
        
        analyseEncoding.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
        
        analyseEncoding.endEncoding()
        analysisCommandBuffer.commit()
        analysisCommandBuffer.waitUntilCompleted()
        
        let resultBuffer = result.contents().bindMemory(to: Float.self, capacity: 0)
        
        print("resultBuffer: ", resultBuffer.pointee)
    }
}
