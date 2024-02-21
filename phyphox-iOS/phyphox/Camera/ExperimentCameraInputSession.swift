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
    
    func transferData(){
        
        
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
        } else {
            // Fallback on earlier versions
        }
    }
    
  
     
    
}
