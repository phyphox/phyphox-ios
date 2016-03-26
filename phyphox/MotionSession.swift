//
//  MotionSession.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreMotion

final class MotionSession {
    lazy var manager = CMMotionManager()
    lazy var altimeter = CMAltimeter()
    
    private func makeQueue() -> NSOperationQueue {
        let q = NSOperationQueue()
        
        q.qualityOfService = .UserInitiated
        
        return q
    }
    
    //MARK: - Altimeter
    
    var altimeterAvailable: Bool {
        get {
            return CMAltimeter.isRelativeAltitudeAvailable()
        }
    }
    
    func getAltimeterData(interval: NSTimeInterval = 0.1, handler: (data: CMAltitudeData?, error: NSError?) -> Void) -> Bool {
        if altimeterAvailable {
            altimeter.startRelativeAltitudeUpdatesToQueue(makeQueue(), withHandler: handler)
            
            return true
        }
        
        return false
    }
    
    func stopAltimeterUpdates() {
        self.altimeter.stopRelativeAltitudeUpdates()
    }
    
    
    //MARK: - Accelerometer
    
    var accelerometerAvailable: Bool {
        get {
            return manager.accelerometerAvailable
        }
    }
    
    func getAccelerometerData(interval: NSTimeInterval = 0.1, handler: (data: CMAccelerometerData?, error: NSError?) -> Void) -> Bool {
        if accelerometerAvailable {
            manager.accelerometerUpdateInterval = interval

            manager.startAccelerometerUpdatesToQueue(makeQueue(), withHandler: handler)
            
            return true
        }
        
        return false
    }
    
    func stopAccelerometerUpdates() {
        self.manager.stopAccelerometerUpdates()
    }
    
    //MARK: - Gyroscope
    
    var gyroAvailable: Bool {
        get {
            return manager.gyroAvailable
        }
    }
    
    func getGyroData(interval: NSTimeInterval = 0.1, handler: (data: CMGyroData?, error: NSError?) -> Void) -> Bool {
        if gyroAvailable {
            manager.gyroUpdateInterval = interval
            manager.startGyroUpdatesToQueue(makeQueue(), withHandler: handler)
            
            return true
        }
        
        return false
    }
    
    func stopGyroUpdates() {
        self.manager.stopGyroUpdates()
    }
    
    
    //MARK: - Magnetometer
    
    var magnetometerAvailable: Bool {
        get {
            return manager.magnetometerAvailable
        }
    }
    
    func getMagnetometerData(interval: NSTimeInterval = 0.1, handler: (data: CMMagnetometerData?, error: NSError?) -> Void) -> Bool {
        if magnetometerAvailable {
            manager.magnetometerUpdateInterval = interval
            manager.startMagnetometerUpdatesToQueue(makeQueue(), withHandler: handler)
            
            return true
        }
        
        return false
    }
    
    func stopMagnetometerUpdates() {
        manager.stopMagnetometerUpdates()
    }
    
    //MARK: - Device Motion
    
    var deviceMotionAvailable: Bool {
        get {
            return manager.deviceMotionAvailable
        }
    }
    
    func getDeviceMotion(interval: NSTimeInterval = 0.1, handler: ((deviceMotion: CMDeviceMotion?, error: NSError?) -> Void)) -> Bool {
        if deviceMotionAvailable {
            manager.deviceMotionUpdateInterval = interval
            manager.showsDeviceMovementDisplay = true
            manager.startDeviceMotionUpdatesToQueue(makeQueue(), withHandler: handler)
            
            return true
        }
        
        return false
    }
    
    func stopDeviceMotionUpdates() {
        manager.stopDeviceMotionUpdates()
    }
    
}
