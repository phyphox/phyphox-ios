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
    let zBuffer: DataBuffer?
    let tBuffer: DataBuffer?
    
    lazy var session: Any? = nil
    
   
    init(timeReference: ExperimentTimeReference, zBuffer: DataBuffer?, tBuffer: DataBuffer?, x1: Float, x2: Float, y1: Float, y2: Float, smooth: Bool) {
        self.initx1 = x1
        self.initx2 = x2
        self.inity1 = y1
        self.inity2 = y2
        self.zBuffer = zBuffer
        self.tBuffer = tBuffer
        self.timeReference = timeReference
        
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

extension ExperimentCameraInput: Equatable {
    static func ==(lhs: ExperimentCameraInput, rhs: ExperimentCameraInput) -> Bool {
        return lhs.initx1 == rhs.initx1 &&
                lhs.initx2 == rhs.initx2 &&
                lhs.inity1 == rhs.inity1 &&
                lhs.inity2 == rhs.inity2 &&
                lhs.timeReference == rhs.timeReference &&
                lhs.zBuffer == rhs.zBuffer &&
                lhs.tBuffer == rhs.tBuffer
    }
}
