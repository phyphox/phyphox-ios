//
//  AnalysingModule.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 18.09.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

@available(iOS 14.0, *)
class AnalyzingModule {
    
    static var metalDevice: MTLDevice?
    static var gpuFunctionLibrary: MTLLibrary?
    
    var selectionState = SelectionState(x1: 0, x2: 0, y1: 0, y2: 0, editable: false)
    
    static func initialize(metalDevice: MTLDevice) {
        self.metalDevice = metalDevice
        self.gpuFunctionLibrary = metalDevice.makeDefaultLibrary()
    }
    
    func loadMetal() {
        //fatalError("Subclasses must implement loadMetal()")
    }
    
    func update(selectionArea: CGRect,
                metalCommandBuffer: MTLCommandBuffer,
                cameraImageTextureY: MTLTexture,
                cameraImageTextureCbCr: MTLTexture) {
        
        let w = cameraImageTextureY.width
        let h = cameraImageTextureY.height
        
        self.selectionState = SelectionState(
            x1: min(max(Float(selectionArea.minX) * Float(w), 0.0), Float(w)),
            x2: min(max(Float(selectionArea.maxX) * Float(w), 0.0), Float(w)),
            y1: min(max(Float(selectionArea.minY) * Float(h), 0.0), Float(h)),
            y2: min(max(Float(selectionArea.maxY) * Float(h), 0.0), Float(h)),
            editable: false
        )
                
        doUpdate(metalCommandBuffer: metalCommandBuffer, cameraImageTextureY: cameraImageTextureY, cameraImageTextureCbCr: cameraImageTextureCbCr)
    }
    
    func doUpdate(metalCommandBuffer: MTLCommandBuffer,
                cameraImageTextureY: MTLTexture,
                cameraImageTextureCbCr: MTLTexture) {
        
        //fatalError("Subclasses must implement doUpdate method()")
    }
    
    func prepareWriteToBuffers() {
        //fatalError("Subclasses must implement writeToBuffers()")
    }
    
    func writeToBuffers() {
        //fatalError("Subclasses must implement writeToBuffers()")
    }
    
    func getSelectedArea() -> (width: Int, height: Int){
        let _width = Int((selectionState.x2 - selectionState.x1 + 1))
        let _height = Int((selectionState.y2 - selectionState.y1 + 1))
        
        return (width: _width, height: _height)
    }
    
}
