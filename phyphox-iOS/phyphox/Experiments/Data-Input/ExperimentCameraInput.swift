//
//  ExperimentCameraInput.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 07.09.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//


import Foundation
import ARKit


final class ExperimentCameraInput {
    
    
    enum CameraOrientation: String, LosslessStringConvertible, CaseIterable {
        case front
        case back
    }

    let initx1: Float
    let initx2: Float
    let inity1: Float
    let inity2: Float
    
    let smooth: Bool
    
    let timeReference: ExperimentTimeReference?
    let zBuffer: DataBuffer?
    let tBuffer: DataBuffer?
    
    lazy var session: Any? = nil
    
    private var queue: DispatchQueue?
    
    
    init(timeReference: ExperimentTimeReference, zBuffer: DataBuffer?, tBuffer: DataBuffer?, x1: Float, x2: Float, y1: Float, y2: Float, smooth: Bool) {

        self.initx1 = x1
        self.initx2 = x2
        self.inity1 = y1
        self.inity2 = y2
        self.zBuffer = zBuffer
        self.tBuffer = tBuffer
        self.smooth = smooth
        self.timeReference = timeReference
        

        if #available(iOS 14.0, *) {
            session = ExperimentCameraInputSession()
            guard let session = session as? ExperimentCameraInputSession else {
                return
            }

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

    
    func start(queue: DispatchQueue) throws {
        guard #available(iOS 14.0, *) else {
            return
        }
        guard let session = session as? ExperimentCameraInputSession else {
            return
        }
        try session.start(queue: queue)
    }
    
    func stop() {
        guard #available(iOS 14.0, *) else {
            return
        }
        guard let session = session as? ExperimentCameraInputSession else {
            return
        }
        session.stop()
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

extension ExperimentCameraInput: Equatable {
    static func ==(lhs: ExperimentCameraInput, rhs: ExperimentCameraInput) -> Bool {
        return lhs.initx1 == rhs.initx1 &&
                lhs.initx2 == rhs.initx2 &&
                lhs.inity1 == rhs.inity1 &&
                lhs.inity2 == rhs.inity2 &&
                lhs.timeReference == rhs.timeReference &&
                lhs.zBuffer == rhs.zBuffer &&
                lhs.tBuffer == rhs.tBuffer &&
                lhs.smooth == rhs.smooth
    }
}

