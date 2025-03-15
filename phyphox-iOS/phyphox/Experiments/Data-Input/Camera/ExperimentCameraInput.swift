//
//  ExperimentCameraInput.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 12.02.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentCameraInput {

    enum AutoExposureStrategy: String, LosslessStringConvertible {
        case mean, avoidOverexposure, avoidUnderexposure
    }
    
    let initx1: Float
    let initx2: Float
    let inity1: Float
    let inity2: Float
    
    let timeReference: ExperimentTimeReference?
    
    var experimentCameraBuffers: ExperimentCameraBuffers?
    let autoExposure: Bool
    let aeStrategy: AutoExposureStrategy

    let locked: [String:Float?]
    let feature: String
    
    lazy var session: Any? = nil
    
   
    init(timeReference: ExperimentTimeReference, luminanceBuffer: DataBuffer?, lumaBuffer: DataBuffer?, hueBuffer: DataBuffer?, saturationBuffer: DataBuffer?, valueBuffer: DataBuffer?, thresholdBuffer: DataBuffer?, shutterSpeedBuffer: DataBuffer?, isoBuffer: DataBuffer?, apertureBuffer: DataBuffer?, tBuffer: DataBuffer?, x1: Float, x2: Float, y1: Float, y2: Float, autoExposure: Bool, aeStrategy: AutoExposureStrategy, locked: [String:Float?], feature: String) {
                
        experimentCameraBuffers = ExperimentCameraBuffers(
            luminanceBuffer: luminanceBuffer,
            lumaBuffer: lumaBuffer,
            hueBuffer: hueBuffer,
            saturationBuffer: saturationBuffer,
            valueBuffer: valueBuffer,
            thresholdBuffer: thresholdBuffer,
            shutterSpeedBuffer: shutterSpeedBuffer,
            isoBuffer: isoBuffer,
            apertureBuffer: apertureBuffer,
            tBuffer: tBuffer
        )
        
        self.initx1 = x1
        self.initx2 = x2
        self.inity1 = y1
        self.inity2 = y2
      
        self.timeReference = timeReference
        self.autoExposure = autoExposure
        self.aeStrategy = aeStrategy
       
        self.locked = locked
        self.feature = feature
        
        guard #available(iOS 14.0, *) else {
            return
        }
        
        session = ExperimentCameraInputSession()
        
        applyCameraInputAttributes()
        
    }
    
    func applyCameraInputAttributes() {
        guard #available(iOS 14.0, *) else {
            return
        }
        
        guard let session = session as? ExperimentCameraInputSession else {
            return
        }
        
        session.initx1 = initx1
        session.initx2 = initx2
        session.inity1 = inity1
        session.inity2 = inity2
        
        session.experimentCameraBuffers = experimentCameraBuffers
        session.timeReference = timeReference
        
        session.autoExposure = autoExposure
        session.aeStrategy = aeStrategy
      
        session.locked = locked
        session.feature = feature
    }
    
    func start(queue: DispatchQueue) throws {
        guard #available(iOS 14.0, *) else {
            return
        }
        guard let session = session as? ExperimentCameraInputSession else {
            return
        }
        
        session.startSession(queue: queue)
    }
    
    func stop() {
        guard #available(iOS 14.0, *) else {
            return
        }
        guard let session = session as? ExperimentCameraInputSession else {
            return
        }
        session.stopSession()
    }
    
    func clear() {
        guard #available(iOS 14.0, *) else {
            return
        }
        guard let session = session as? ExperimentCameraInputSession else {
            return
        }
        session.clear()
    }
    
}

class ExperimentCameraBuffers {
    var luminanceBuffer, lumaBuffer, hueBuffer, saturationBuffer, valueBuffer, thresholdBuffer, shutterSpeedBuffer, isoBuffer, apertureBuffer, tBuffer: DataBuffer?
    
    init(luminanceBuffer: DataBuffer? = nil, lumaBuffer: DataBuffer? = nil, hueBuffer: DataBuffer? = nil, saturationBuffer: DataBuffer? = nil, valueBuffer: DataBuffer? = nil, thresholdBuffer: DataBuffer?, shutterSpeedBuffer: DataBuffer? = nil, isoBuffer: DataBuffer? = nil, apertureBuffer: DataBuffer? = nil, tBuffer: DataBuffer? = nil) {
        self.luminanceBuffer = luminanceBuffer
        self.lumaBuffer = lumaBuffer
        self.hueBuffer = hueBuffer
        self.saturationBuffer = saturationBuffer
        self.valueBuffer = valueBuffer
        self.thresholdBuffer = thresholdBuffer
        self.shutterSpeedBuffer = shutterSpeedBuffer
        self.isoBuffer = isoBuffer
        self.apertureBuffer = apertureBuffer
        self.tBuffer = tBuffer
    }
}

extension ExperimentCameraInput: Equatable {
    static func ==(lhs: ExperimentCameraInput, rhs: ExperimentCameraInput) -> Bool {
        return lhs.initx1 == rhs.initx1 &&
                lhs.initx2 == rhs.initx2 &&
                lhs.inity1 == rhs.inity1 &&
                lhs.inity2 == rhs.inity2 &&
                lhs.timeReference == rhs.timeReference &&
                lhs.experimentCameraBuffers?.luminanceBuffer == rhs.experimentCameraBuffers?.luminanceBuffer &&
                lhs.experimentCameraBuffers?.lumaBuffer == rhs.experimentCameraBuffers?.lumaBuffer &&
                lhs.experimentCameraBuffers?.hueBuffer == rhs.experimentCameraBuffers?.hueBuffer &&
                lhs.experimentCameraBuffers?.saturationBuffer == rhs.experimentCameraBuffers?.saturationBuffer &&
                lhs.experimentCameraBuffers?.valueBuffer == rhs.experimentCameraBuffers?.valueBuffer &&
                lhs.experimentCameraBuffers?.shutterSpeedBuffer == rhs.experimentCameraBuffers?.shutterSpeedBuffer &&
                lhs.experimentCameraBuffers?.isoBuffer == rhs.experimentCameraBuffers?.isoBuffer &&
                lhs.experimentCameraBuffers?.apertureBuffer == rhs.experimentCameraBuffers?.apertureBuffer &&
                lhs.experimentCameraBuffers?.tBuffer == rhs.experimentCameraBuffers?.tBuffer
    }
}
