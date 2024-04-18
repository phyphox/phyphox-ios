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
    
    var zBuffer: DataBuffer?
    
    var tBuffer: DataBuffer?
    
    var x1: Float = 0.4
    var x2: Float = 0.6
    var y1: Float = 0.4
    var y2: Float = 0.6
    
    lazy var cameraModel: Any? = nil
    
    var autoExposure: Bool = true
    var exposureAdjustmentLevel: Int = 0
    var locked: String = ""
    var feature: String = ""
    var analysis: String = ""
    
    var delegate : CameraGUIDelegate?
    
    func initializeCameraModel(){
        
        
        if #available(iOS 14.0, *) {
            cameraModel = CameraModel()
            
            guard let cameraModel = cameraModel as? CameraModel else {
                return
            }
            
            cameraModel.x1 = x1
            cameraModel.x2 = x2
            cameraModel.y1 = y1
            cameraModel.y2 = y2
            
            cameraModel.metalRenderer.timeReference = timeReference
            cameraModel.metalRenderer.zBuffer = zBuffer
            cameraModel.metalRenderer.tBuffer =  tBuffer
            
            cameraModel.exposureSettingLevel = exposureAdjustmentLevel
        } else {
            // Fallback on earlier versions
        }
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
  
    
    public func attachDelegate(delegate: CameraGUIDelegate) {
        self.delegate = delegate
        delegate.updateResolution(resolution: CGSize(width: 300, height: 300))
    }
    
}
