//
//  ExperimentCameraInputSession.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 14.02.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

class ExperimentCameraInputSession: NSObject {
    var timeReference: ExperimentTimeReference?
    
    var experimentCameraBuffers: ExperimentCameraBuffers?
 
    var x1: Float = 0.4
    var x2: Float = 0.6
    var y1: Float = 0.4
    var y2: Float = 0.6
    
    lazy var cameraModel: Any? = nil
    
    var autoExposure: Bool = true
    var locked: String = ""
    var feature: String = ""
    var analysis: String = ""
    
    var delegate : CameraGUIDelegate?
    
    @available(iOS 14.0, *)
    func initializeCameraModelAndRunSession(uiView: ExperimentCameraUIView){
        
        // During model instantiation, the camera session runs
        cameraModel = CameraModel()
        
        guard let cameraModel = cameraModel as? CameraModel else {
            return
        }
        
        cameraModel.x1 = x1
        cameraModel.x2 = x2
        cameraModel.y1 = y1
        cameraModel.y2 = y2
        
        cameraModel.metalRenderer.timeReference = timeReference
        cameraModel.metalRenderer.cameraBuffers = experimentCameraBuffers
       
        
        cameraModel.locked = locked
        
        delegate = uiView as CameraGUIDelegate
        
        uiView.updateResolution(resolution: cameraModel.cameraSettingsModel.resolution)
        
        uiView.cameraSelectionDelegate = cameraModel as any CameraSelectionDelegate
        uiView.cameraViewDelegete = cameraModel as any CameraViewDelegate
        
    }
    
    func startSession(){
        if #available(iOS 14.0, *) {
            guard let cameraModel = cameraModel as? CameraModel else {
                return
            }
            
            cameraModel.startSession()
            
        } else {
            // Fallback on earlier versions
        }
    }
    
    func stopSession(){
        if #available(iOS 14.0, *) {
            guard let cameraModel = cameraModel as? CameraModel else {
                return
            }
            
            cameraModel.stopSession()
            
        } else {
            // Fallback on earlier versions
        }
    }
    
    func endSession(){
        if #available(iOS 14.0, *) {
            guard let cameraModel = cameraModel as? CameraModel else {
                return
            }
            
            cameraModel.endSession()
            
        } else {
            // Fallback on earlier versions
        }
    }
    
    
    func clear() {
        
    }
    
}
