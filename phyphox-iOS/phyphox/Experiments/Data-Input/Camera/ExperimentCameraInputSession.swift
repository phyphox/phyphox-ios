//
//  ExperimentCameraInputSession.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 14.02.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

protocol CameraGUIDelegate {
    func updateResolution(resolution: CGSize)
}

@available(iOS 14.0, *)
protocol CameraModelOwner {
    var cameraModel: CameraModel? { get }
    func updateResolution(_ resolution: CGSize)
}

@available(iOS 14.0, *)
class ExperimentCameraInputSession: NSObject, CameraModelOwner {
    var initx1: Float = 0.0
    var initx2: Float = 0.0
    var inity1: Float = 0.0
    var inity2: Float = 0.0
    
    var timeReference: ExperimentTimeReference?
    
    var experimentCameraBuffers: ExperimentCameraBuffers?
 
    var cameraModel: CameraModel?
    var sessionInitialized = false
    
    var autoExposure: Bool = true
    var aeStrategy = ExperimentCameraInput.AutoExposureStrategy.mean
    var locked: [String:Float?] = [:]
    var feature: String = ""
    
    var delegates : [CameraGUIDelegate] = []
    
    override init() {
        super.init()
    }
    
    func initializeCameraModelAndRunSession(){
        cameraModel = CameraModel(owner: self)
        cameraModel?.x1 = initx1
        cameraModel?.x2 = initx2
        cameraModel?.y1 = inity1
        cameraModel?.y2 = inity2
        cameraModel?.analyzingRenderer.cameraModelOwner = self
        cameraModel?.analyzingRenderer.timeReference = timeReference
        cameraModel?.analyzingRenderer.initializeCameraBuffer(cameraBuffers: experimentCameraBuffers)
        
        cameraModel?.autoExposureEnabled = autoExposure
        cameraModel?.locked = locked
        cameraModel?.aeStrategy = aeStrategy
        
        sessionInitialized = true
    }
    
    func attachDelegate(_ delegate: CameraGUIDelegate) -> CameraModelOwner {
        self.delegates.append(delegate)
        if !sessionInitialized {
            initializeCameraModelAndRunSession()
        }
        if let resolution = cameraModel?.cameraSettingsModel.resolution {
            delegate.updateResolution(resolution: resolution)
        }
        return self
    }
    
    func updateResolution(_ resolution: CGSize) {
        cameraModel?.cameraSettingsModel.resolution = resolution
        for delegate in delegates {
            delegate.updateResolution(resolution: resolution)
        }
    }
    
    func startSession(queue: DispatchQueue){
        if !sessionInitialized {
            initializeCameraModelAndRunSession()
        }
        cameraModel?.startSession(queue: queue)
    }
    
    func stopSession(){
        cameraModel?.stopSession()
    }
    
    func endSession(){
        cameraModel?.endSession()
        cameraModel = nil
        sessionInitialized = false
    }
    
    
    func clear() {
        
    }
    
}
