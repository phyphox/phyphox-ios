//
//  ExperimentCameraInputSession.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 14.02.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

@available(iOS 14.0, *)
class ExperimentCameraInputSession: NSObject {
    var timeReference: ExperimentTimeReference?
    
    var experimentCameraBuffers: ExperimentCameraBuffers?
 
    var x1: Float = 0.4
    var x2: Float = 0.6
    var y1: Float = 0.4
    var y2: Float = 0.6
    
    lazy var cameraModel: CameraModel? = nil
    
    var autoExposure: Bool = true
    var locked: String = ""
    var feature: String = ""
    var analysis: String = ""
    
    var delegates : [CameraGUIDelegate] = []
    
    func initializeCameraModelAndRunSession(){
        // During model instantiation, the camera session runs
        cameraModel = CameraModel()
        
        guard let cameraModel = cameraModel else {
            return
        }
        
        cameraModel.x1 = x1
        cameraModel.x2 = x2
        cameraModel.y1 = y1
        cameraModel.y2 = y2
        
        cameraModel.metalRenderer.timeReference = timeReference
        cameraModel.metalRenderer.initializeCameraBuffer(cameraBuffers: experimentCameraBuffers)
       
        
        cameraModel.locked = locked
    }
    
    func attachDelegate(_ delegate: CameraGUIDelegate) -> CameraModelState? {
        self.delegates.append(delegate)
        if cameraModel == nil {
            initializeCameraModelAndRunSession()
        }
        guard let cameraModel = cameraModel else {
            return nil
        }
        delegate.updateResolution(resolution: cameraModel.cameraSettingsModel.resolution)
        return cameraModel
    }
    
    func startSession(){
        if cameraModel == nil {
            initializeCameraModelAndRunSession()
        }
        cameraModel?.startSession()
    }
    
    func stopSession(){
        cameraModel?.stopSession()
    }
    
    func endSession(){
        cameraModel?.endSession()
    }
    
    
    func clear() {
        
    }
    
}
