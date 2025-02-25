//
//  AnalysingModule.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 18.09.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

@available(iOS 14.0, *)
class AnalysingModule {
    
    static var metalDevice: MTLDevice?
    static var gpuFunctionLibrary: MTLLibrary?
    
    static func initialize(metalDevice: MTLDevice) {
        self.metalDevice = metalDevice
        self.gpuFunctionLibrary = metalDevice.makeDefaultLibrary()
    }
    
    func loadMetal(){
        //fatalError("Subclasses must implement loadMetal()")
    }
    
    func update(selectionArea: SelectionState,
                metalCommandBuffer: MTLCommandBuffer,
                cameraImageTextureY: MTLTexture,
                cameraImageTextureCbCr: MTLTexture){
        
        //fatalError("Subclasses must implement update method()")
    }
    
    func writeToBuffers(){
        //fatalError("Subclasses must implement writeToBuffers()")
    }
    
}
