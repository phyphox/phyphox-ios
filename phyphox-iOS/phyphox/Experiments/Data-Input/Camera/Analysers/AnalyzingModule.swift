//
//  AnalysingModule.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 18.09.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

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
        
        //Whole pixels, half-open: the kernels process [x1, x2) x [y1, y2) and the means divide by exactly that count.
        //(Fractional bounds with an inclusive x2 used to count one row and one column too many - 0.7 % low on a
        //typical region, an out-of-bounds read at the frame edge - which the synthetic-frame tests exposed.)
        func pixelBound(_ fraction: CGFloat, _ size: Int, roundingUp: Bool) -> Float {
            let clamped = min(max(fraction, 0.0), 1.0) * CGFloat(size)
            return Float(roundingUp ? ceil(clamped) : floor(clamped))
        }
        self.selectionState = SelectionState(
            x1: pixelBound(selectionArea.minX, w, roundingUp: false),
            x2: pixelBound(selectionArea.maxX, w, roundingUp: true),
            y1: pixelBound(selectionArea.minY, h, roundingUp: false),
            y2: pixelBound(selectionArea.maxY, h, roundingUp: true),
            editable: false
        )
                
        //Nothing to dispatch for an empty selection (x1 == x2 or y1 == y2); the analyzers then report NaN or empty spectra
        guard !selectionIsEmpty else { return }
        
        doUpdate(metalCommandBuffer: metalCommandBuffer, cameraImageTextureY: cameraImageTextureY, cameraImageTextureCbCr: cameraImageTextureCbCr)
    }
    
    var selectionIsEmpty: Bool {
        let area = getSelectedArea()
        return area.width == 0 || area.height == 0
    }
    
    func doUpdate(metalCommandBuffer: MTLCommandBuffer,
                cameraImageTextureY: MTLTexture,
                cameraImageTextureCbCr: MTLTexture) {
        
        //fatalError("Subclasses must implement doUpdate method()")
    }
    
    func prepareWriteToBuffers(cameraSettings: CameraSettingsModel) {
        //fatalError("Subclasses must implement writeToBuffers()")
    }
    
    func writeToBuffers() {
        //fatalError("Subclasses must implement writeToBuffers()")
    }
    
    func getSelectedArea() -> (width: Int, height: Int){
        let _width = max(0, Int(selectionState.x2) - Int(selectionState.x1))
        let _height = max(0, Int(selectionState.y2) - Int(selectionState.y1))
        
        return (width: _width, height: _height)
    }
    
}
