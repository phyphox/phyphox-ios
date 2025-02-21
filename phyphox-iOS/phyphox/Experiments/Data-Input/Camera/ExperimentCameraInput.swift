//
//  ExperimentCameraInput.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 12.02.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentCameraInput {
    
    let initx1: Float
    let initx2: Float
    let inity1: Float
    let inity2: Float
    
    let timeReference: ExperimentTimeReference?
    
    var experimentCameraBuffers: ExperimentCameraBuffers?
    let autoExposure: Bool

    let locked: String
    let feature: String
    let analysis: String
    
    lazy var session: Any? = nil
    
   
    init(timeReference: ExperimentTimeReference, luminanceBuffer: DataBuffer?, lumaBuffer: DataBuffer?, hueBuffer: DataBuffer?, saturationBuffer: DataBuffer?, valueBuffer: DataBuffer?, thresholdBuffer: DataBuffer?, shutterSpeedBuffer: DataBuffer?, isoBuffer: DataBuffer?, apertureBuffer: DataBuffer?, tBuffer: DataBuffer?, x1: Float, x2: Float, y1: Float, y2: Float, smooth: Bool, autoExposure: Bool,  locked: String, feature: String, analysis: String) {
                
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
       
        self.locked = locked
        self.feature = feature
        self.analysis = analysis
        
        guard #available(iOS 14.0, *) else {
            return
        }
        
        session = ExperimentCameraInputSession()
        guard let session = session as? ExperimentCameraInputSession else {
            return
        }
        
        session.x1 = x1
        session.x2 = x2
        session.y1 = y1
        session.y2 = y2
        session.experimentCameraBuffers = experimentCameraBuffers
        session.timeReference = timeReference
        
        session.autoExposure = autoExposure
      
        session.locked = locked
        session.feature = feature
        session.analysis = analysis
        
        
    }
    
    func start() throws {
        guard #available(iOS 14.0, *) else {
            return
        }
        guard let session = session as? ExperimentCameraInputSession else {
            return
        }
        
        session.startSession()
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
