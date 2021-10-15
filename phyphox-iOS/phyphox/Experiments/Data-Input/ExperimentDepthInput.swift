//
//  ExperimentDepthInput.swift
//  phyphox
//
//  Created by Sebastian Staacks on 12.10.21.
//  Copyright © 2021 RWTH Aachen. All rights reserved.
//

import Foundation
import ARKit

enum DepthInputError : Error {
    case sensorUnavailable
}

final class ExperimentDepthInput {
    
    enum DepthExtractionMode: String, LosslessStringConvertible, CaseIterable {
        case average
        case closest
    }

    let mode: ExperimentDepthInput.DepthExtractionMode
    let initx1: Float
    let initx2: Float
    let inity1: Float
    let inity2: Float
    
    let smooth: Bool
    
    let timeReference: ExperimentTimeReference?
    let zBuffer: DataBuffer?
    let tBuffer: DataBuffer?
    
    @available(iOS 14.0, *)
    lazy var session = ExperimentDepthInputSession()
    
    private var queue: DispatchQueue?
    
    init(timeReference: ExperimentTimeReference, zBuffer: DataBuffer?, tBuffer: DataBuffer?, mode: DepthExtractionMode, x1: Float, x2: Float, y1: Float, y2: Float, smooth: Bool) {
        self.mode = mode
        self.initx1 = x1
        self.initx2 = x2
        self.inity1 = y1
        self.inity2 = y2
        self.zBuffer = zBuffer
        self.tBuffer = tBuffer
        self.smooth = smooth
        self.timeReference = timeReference
        
        if #available(iOS 14.0, *) {
            session.mode = mode
            session.x1 = x1
            session.x2 = x2
            session.y1 = y1
            session.y2 = y2
            session.zBuffer = zBuffer
            session.tBuffer = tBuffer
            session.timeReference = timeReference
            session.smooth = smooth
        }
    }
    
    func verifySensorAvailibility() throws {
        guard #available(iOS 14.0, *) else {
            throw DepthInputError.sensorUnavailable
        }
        if !ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            throw DepthInputError.sensorUnavailable
        }
    }
    
    func start(queue: DispatchQueue) {
        guard #available(iOS 14.0, *) else {
            return
        }
        session.start(queue: queue)
    }
    
    func stop() {
        guard #available(iOS 14.0, *) else {
            return
        }
        session.stop()
    }
    
    func clear() {
        guard #available(iOS 14.0, *) else {
            return
        }
        session.clear()
    }
    
}

extension ExperimentDepthInput: Equatable {
    static func ==(lhs: ExperimentDepthInput, rhs: ExperimentDepthInput) -> Bool {
        return lhs.mode == rhs.mode &&
                lhs.initx1 == rhs.initx1 &&
                lhs.initx2 == rhs.initx2 &&
                lhs.inity1 == rhs.inity1 &&
                lhs.inity2 == rhs.inity2 &&
                lhs.timeReference == rhs.timeReference &&
                lhs.zBuffer == rhs.zBuffer &&
                lhs.tBuffer == rhs.tBuffer &&
                lhs.smooth == rhs.smooth
    }
}
