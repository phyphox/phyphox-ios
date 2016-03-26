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
            manager.startDeviceMotionUpdatesToQueue(makeQueue(), withHandler: handler)
            
            return true
        }
        
        return false
    }
    
    func stopDeviceMotionUpdates() {
        manager.stopDeviceMotionUpdates()
    }
    
   /*
    func getAccelerationFromDeviceMotion (interval: NSTimeInterval = 0.1, values: ((x:Double?, y:Double?, z:Double?, error: NSError?) -> Void)) -> Bool {
        var valX: Double?
        var valY: Double?
        var valZ: Double?
        
        if deviceMotionAvailable {
            manager.deviceMotionUpdateInterval = interval
            manager.startDeviceMotionUpdatesToQueue(NSOperationQueue()){
                (data: CMDeviceMotion?, error: NSError?) in
                if (data != nil) {
                    valX = data!.userAcceleration.x
                    valY = data!.userAcceleration.y
                    valZ = data!.userAcceleration.z
                }
                
                values(x: valX, y: valY, z: valZ, error: error)
            }
            
            return true
        }
        
        return false
    }
    
    func getGravityAccelerationFromDeviceMotion (interval: NSTimeInterval = 0.1, values: ((x:Double?, y:Double?, z:Double?, error: NSError?) -> Void)) -> Bool {
        var valX: Double?
        var valY: Double?
        var valZ: Double?
        
        if deviceMotionAvailable{
            manager.deviceMotionUpdateInterval = interval
            manager.startDeviceMotionUpdatesToQueue(NSOperationQueue()){
                (data: CMDeviceMotion?, error: NSError?) in
                if data != nil {
                    valX = data!.gravity.x
                    valY = data!.gravity.y
                    valZ = data!.gravity.z
                }
                
                values(x: valX, y: valY, z: valZ, error: error)
            }
            
            return true
        }
        
        return false
    }
    
    func getAttitudeFromDeviceMotion (interval: NSTimeInterval = 0.1, values: ((attitude: CMAttitude?, error: NSError?) -> Void)) -> Bool {
        
        if deviceMotionAvailable{
            manager.deviceMotionUpdateInterval = interval
            manager.startDeviceMotionUpdatesToQueue(NSOperationQueue()){
                (data: CMDeviceMotion?, error: NSError?) in
                values(attitude: data?.attitude, error: error)
            }
            
            return true
        }
        
        return false
    }
    
    
    func getRotationRateFromDeviceMotion(interval: NSTimeInterval = 0.1, values: ((x:Double?, y:Double?, z:Double?, error: NSError?) -> Void)) -> Bool {
        var valX: Double?
        var valY: Double?
        var valZ: Double?
        
        if deviceMotionAvailable {
            manager.deviceMotionUpdateInterval = interval
            manager.startDeviceMotionUpdatesToQueue(NSOperationQueue()){
                (data: CMDeviceMotion?, error: NSError?) in
                if data != nil {
                    valX = data!.rotationRate.x
                    valY = data!.rotationRate.y
                    valZ = data!.rotationRate.z
                }
                
                values(x: valX, y: valY, z: valZ, error: error)
            }
            
            return true
        }
        
        return false
    }
    
    
    func getMagneticFieldFromDeviceMotion(interval: NSTimeInterval = 0.1, values: ((x:Double?, y:Double?, z:Double?, accuracy: Int32?, error: NSError?) -> Void)) -> Bool {
        var valX: Double?
        var valY: Double?
        var valZ: Double?
        
        var valAccuracy: Int32?
        
        if deviceMotionAvailable {
            manager.deviceMotionUpdateInterval = interval
            manager.startDeviceMotionUpdatesToQueue(NSOperationQueue()){
                (data: CMDeviceMotion?, error: NSError?) in
                
                if (data != nil) {
                    valX = data!.magneticField.field.x
                    valY = data!.magneticField.field.y
                    valZ = data!.magneticField.field.z
                    valAccuracy = data!.magneticField.accuracy.rawValue
                }
                
                values(x: valX, y: valY, z: valZ, accuracy: valAccuracy, error: error)
            }
            
            return true
        }
        
        return false
    }*/
    
}
